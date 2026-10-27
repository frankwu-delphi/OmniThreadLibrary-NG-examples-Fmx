unit tthreadCommMain;

interface

uses
  System.Messaging, System.SysUtils, System.Variants, System.Classes, FMX.Graphics,
  FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.Types, System.Types,
  System.UITypes,

  OtlContainerObserver,
  OtlComm, FMX.ListBox, FMX.Layouts, FMX.Controls.Presentation;

type
  TfrmTThreadComm = class(TForm)
    btn: TButton;
    lbLog: TListBox;
    Button1: TButton;
    Button2: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure btnClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
  private
    FCommandQueue   : TOmniMessageQueue;
    FResponseQueue  : TOmniMessageQueue;
    FResponseObserver: IOmniContainerMainThreadObserver;
    FWorker         : TThread;
    procedure DrainResponses;
    procedure LogOnMain(const msg: string);
    procedure Query(value: integer);
    procedure StartWorker;
    procedure StopWorker;
  public
  end;

var
  frmTThreadComm: TfrmTThreadComm;

implementation

uses
  SyncObjs;

{$R *.fmx}

type
  TWorker = class(TThread)
  strict private
    FCommandQueue : TOmniMessageQueue;
    FResponseQueue: TOmniMessageQueue;
    FStopEvent    : TEvent;
  protected
    procedure Execute; override;
  public
    constructor Create(commandQueue, responseQueue: TOmniMessageQueue);
    destructor Destroy; override;
    procedure Stop;
  end;

{ TfrmTThreadComm }

procedure TfrmTThreadComm.btnClick(Sender: TObject);
begin
  Query(42);
end;

procedure TfrmTThreadComm.Button1Click(Sender: TObject);
begin
  Query(Random(1000));
  Query(Random(1000));
end;

procedure TfrmTThreadComm.Button2Click(Sender: TObject);
var
  th1: TThread;
  th2: TThread;
begin
  th1 := TThread.CreateAnonymousThread(
    procedure
    begin
      Query(Random(1000));
    end);
  th2 := TThread.CreateAnonymousThread(
    procedure
    begin
      Query(Random(1000));
    end);
  th1.Start;
  th2.Start;
end;

procedure TfrmTThreadComm.FormDestroy(Sender: TObject);
begin
  StopWorker;
end;

procedure TfrmTThreadComm.StartWorker;
begin
  FCommandQueue := TOmniMessageQueue.Create(1000);

  // Response queue does not need its own IOmniEvent observer: the main-thread
  // observer below handles UI delivery. Suppressing the default observer keeps
  // the queue lean.
  FResponseQueue := TOmniMessageQueue.Create(1000, false);

  // Attach a cross-platform main-thread dispatcher. Each Enqueue from the
  // worker schedules a single DrainResponses call on the main thread; extra
  // enqueues arriving before the drain runs coalesce into one.
  FResponseObserver := CreateContainerMainThreadObserver(DrainResponses);
  FResponseQueue.ContainerSubject.Attach(FResponseObserver, coiNotifyOnAllInserts);

  FWorker := TWorker.Create(FCommandQueue, FResponseQueue);
end;

procedure TfrmTThreadComm.StopWorker;
begin
  if assigned(FWorker) then begin
    TWorker(FWorker).Stop;
    FWorker.WaitFor;
    FreeAndNil(FWorker);
  end;

  // Worker is gone, so no more Notify calls can queue drain closures.
  // Shut the observer down so any closure already in flight becomes a no-op
  // before the response queue (and the form's state it would touch) is freed.
  if assigned(FResponseObserver) then begin
    FResponseObserver.Shutdown;
    if assigned(FResponseQueue) then
      FResponseQueue.ContainerSubject.Detach(FResponseObserver, coiNotifyOnAllInserts);
    FResponseObserver := nil;
  end;

  FreeAndNil(FResponseQueue);
  FreeAndNil(FCommandQueue);
end;

procedure TfrmTThreadComm.FormCreate(Sender: TObject);
begin
  StartWorker;
end;

procedure TfrmTThreadComm.DrainResponses;
var
  msg: TOmniMessage;
begin
  while FResponseQueue.TryDequeue(msg) do
    lbLog.ItemIndex := lbLog.Items.Add(msg.MsgData);
end;

procedure TfrmTThreadComm.LogOnMain(const msg: string);
begin
  if TThread.CurrentThread.ThreadID = MainThreadID then
    lbLog.ItemIndex := lbLog.Items.Add(msg)
  else
    TThread.Queue(nil,
      procedure
      begin
        lbLog.ItemIndex := lbLog.Items.Add(msg);
      end);
end;

procedure TfrmTThreadComm.Query(value: integer);
begin
  LogOnMain(Format('%d * 2 ?', [value]));
  if not FCommandQueue.Enqueue(TOmniMessage.Create(0 {ignored}, value)) then
    raise Exception.Create('Command queue is full!');
end;

{ TWorker }

constructor TWorker.Create(commandQueue, responseQueue: TOmniMessageQueue);
begin
  inherited Create;
  FCommandQueue := commandQueue;
  FResponseQueue := responseQueue;
  FStopEvent := TEvent.Create;
end;

destructor TWorker.Destroy;
begin
  FreeAndNil(FStopEvent);
  inherited;
end;

procedure TWorker.Execute;
var
  msg: TOmniMessage;
begin
  while FStopEvent.WaitFor(50) = wrTimeout do
  begin
    while FCommandQueue.TryDequeue(msg) do
    begin
      if not FResponseQueue.Enqueue(TOmniMessage.Create(0 {ignored}, Format('= %d', [msg.MsgData.AsInteger * 2]))) then
        raise Exception.Create('Response queue is full!');
    end;
  end;
end;

procedure TWorker.Stop;
begin
  FStopEvent.SetEvent;
end;

end.
