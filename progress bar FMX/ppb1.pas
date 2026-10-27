// "Updating a Progress Bar From a Parallel For Loop"
//  http://www.thedelphigeek.com/2015/10/updating-progress-bar-from-parallel-for.html

unit ppb1;

interface

uses
  System.SysUtils, System.Variants, System.Classes, FMX.Graphics, System.Types,
  FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.ExtCtrls, FMX.Types,
  FMX.Controls.Presentation,  System.UITypes, System.Messaging,

  System.Threading,

  OtlCommon,
  OtlComm,
  OtlTask,
  OtlTaskControl,
  OtlParallel;

type
    TMyCustomMessage = class(TMessage)
    private
      FData: Integer;
    public
      constructor Create(const AData: Integer);
      property Data: Integer read FData;
    end;

  TfrmUpdateProgressBar = class(TForm)
    pbParallel: TProgressBar;
    btnPPLMessage: TButton;
    btnPPLWithQueue: TButton;
    btnOTLWithMessage: TButton;
    btnPPLWithTimer: TButton;
    btnOTLWithTimer: TButton;
    btnPPLAsyncAwait: TButton;
    btnTThreadAsyncAwait: TButton;
    tmrUpdateProgress: TTimer;
    procedure btnPPLMessageClick(Sender: TObject);
    procedure btnPPLWithQueueClick(Sender: TObject);
    procedure btnOTLWithMessageClick(Sender: TObject);
    procedure btnPPLWithTimerClick(Sender: TObject);
    procedure btnOTLWithTimerClick(Sender: TObject);
    procedure btnPPLAsyncAwaitClick(Sender: TObject);
    procedure btnTThreadAsyncAwaitClick(Sender: TObject);
    procedure tmrUpdateProgressTimer(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FParallelFor: IOmniParallelSimpleLoop;
    FProcessed: TOmniAlignedInt32;
    FProgress: integer;
    FTask: ITask;
    FTotal: integer;
    procedure AfterTest;
    procedure BeforeTest;
    function MakeUpdater(newPos: integer): TThreadProcedure;
    procedure CustomMessageHandler(const Sender: TObject; const M: TMessage);
  end;

var
  frmUpdateProgressBar: TfrmUpdateProgressBar;

implementation

uses
  System.SyncObjs;

{$R *.fmx}

constructor TMyCustomMessage.Create(const AData: Integer);
begin
  inherited Create;
  FData := AData;
end;

// PPL version of Async/Await.

procedure AsyncAwait(async, await: TProc);
begin
  TTask.Run(
    procedure
    begin
      async();

      TThread.Queue(nil,
        procedure
        begin
          await();
        end
      ); // TThread.Queue
    end
  ); //TTask.Run
end;

// TThread version of Async/Await.

procedure AsyncAwaitTh(async, await: TProc);
begin
  TThread.CreateAnonymousThread(
    procedure
    begin
      async();

      TThread.Queue(nil,
        procedure
        begin
          await();
        end
      ); // TThread.Queue
    end
  ).Start;
end;

procedure TfrmUpdateProgressBar.AfterTest;
var
  i: integer;
begin
  for i := 0 to ComponentCount - 1 do
    if Components[i] is TButton then
      TButton(Components[i]).Enabled := true;
  FTask := nil;
  FParallelFor := nil;
end;

procedure TfrmUpdateProgressBar.BeforeTest;
var
  i: integer;
begin
  for i := 0 to ComponentCount - 1 do
    if Components[i] is TButton then
      TButton(Components[i]).Enabled := false;
  pbParallel.Value := 0;
end;

procedure TfrmUpdateProgressBar.btnOTLWithMessageClick(Sender: TObject);
var
  AValue: Integer;
begin
  BeforeTest;

  FParallelFor := Parallel.For(1, 1000)
    .NoWait
    .TaskConfig(Parallel.TaskConfig.OnTerminated(AfterTest));

  FParallelFor.Execute(
    procedure (i: integer)
    var
      new: integer;
    begin
      Sleep(10); //do the work
      new := FProcessed.Increment; // increment the shared counter
      if new mod 10 = 0 then
      begin
        AValue :=  Round(new / 1000 * 100);
        TMessageManager.DefaultManager.SendMessage(Self, TMyCustomMessage.Create(AValue));
      end;
    end
  ); // Parallel.For
end;

procedure TfrmUpdateProgressBar.btnOTLWithTimerClick(Sender: TObject);
begin
  BeforeTest;
  FProcessed.Value := 0;
  FTotal := 1000;
  tmrUpdateProgress.Enabled := true;

  FParallelFor := Parallel.For(1, 1000)
    .NoWait
    .TaskConfig(Parallel.TaskConfig.OnTerminated(
      procedure
      begin
        // Disable the timer when everything is processed.
        pbParallel.Value := 100;
        tmrUpdateProgress.Enabled := false;
        AfterTest;
      end));

  FParallelFor.Execute(
    procedure (i: integer)
    begin
      Sleep(10); //do the work
      FProcessed.Increment; // increment the shared counter
    end
  ); // Parallel.For
end;

procedure TfrmUpdateProgressBar.btnPPLAsyncAwaitClick(Sender: TObject);
begin
  BeforeTest; //disable buttons

  AsyncAwait(
    procedure
    begin
      Sleep(1000);
    end,
    procedure
    begin
      AfterTest; //enable buttons
    end);
end;

procedure TfrmUpdateProgressBar.btnPPLMessageClick(Sender: TObject);
var
  AValue: Integer;
begin
  BeforeTest;

  // Local copy of a form handle. As I've said in the presentation - don't access the
  // UI from a thread! (Although in this case that will not cause any problems - but
  // it is always best to stay on the safe side.)


  // While the parallel code is running, main form must process messages, so we have
  // to push a TParallel.For into background by wrapping it inside a task.

  FTask := TTask.Run(
    procedure
    var
      processed: integer; // shared counter
      total    : integer; // total number of items to be processed
    begin
      processed := 0;
      total := 1000;
      TParallel.For(1, 1000,
        procedure (i: integer)
        var
          new: integer;
        begin
          Sleep(10); //do the work
          new := TInterlocked.Increment(processed); // increment the shared counter
          if (new mod 10) = 0 then // update the progress bar every 10 processed items
          begin
            AValue :=  Round(new / total * 100);
            TMessageManager.DefaultManager.SendMessage(Self, TMyCustomMessage.Create(AValue));
          end;
        end
      ); // TParallel.For

      // Update the UI
      TThread.Queue(nil, AfterTest);
    end
  ); // TTask.Run
end;

function TfrmUpdateProgressBar.MakeUpdater(newPos: integer): TThreadProcedure;
begin
  Result :=
    procedure
    begin
      if newPos > pbParallel.Value then
        pbParallel.Value := newPos;
    end;
end;

procedure TfrmUpdateProgressBar.btnPPLWithQueueClick(Sender: TObject);
begin
  BeforeTest;

  // While the parallel code is running, main form must process messages, so we have
  // to push a TParallel.For into background by wrapping it inside a task.

  FTask := TTask.Run(
    procedure
    var
      processed: integer; // shared counter
      total    : integer; // total number of items to be processed
    begin
      processed := 0;
      total := 1000;
      TParallel.For(1, 1000,
        procedure (i: integer)
        var
          new: integer;
          upd: TThreadProcedure;
        begin
          Sleep(10); //do the work
          new := TInterlocked.Increment(processed); // increment the shared counter
          if (new mod 10) = 0 then begin // update the progress bar every 10 processed items
            upd := MakeUpdater(Round(new/total*100));
            TThread.Queue(nil, upd);
          end;
        end
      ); // TParallel.For

      // Update the UI
      TThread.Queue(nil, AfterTest);
    end
  ); // TTask.Run
end;

procedure TfrmUpdateProgressBar.btnPPLWithTimerClick(Sender: TObject);
begin
  BeforeTest;
  FProgress := 0;
  FTotal := 1000;
  tmrUpdateProgress.Enabled := true;

  // While the parallel code is running, main form must process messages, so we have
  // to push a TParallel.For into background by wrapping it inside a task.

  FTask := TTask.Run(
    procedure
    var
      total    : integer; // total number of items to be processed
    begin
      total := 1000;
      TParallel.For(1, 1000,
        procedure (i: integer)
        begin
          Sleep(10); //do the work
          TInterlocked.Increment(FProgress); // increment the shared counter
        end
      ); // TParallel.For

      // Disable the timer when everything is processed.
      TThread.Queue(nil,
        procedure
        begin
          // We have no idea if timer proc 'saw' FProgress = 100 so let's force the last
          // update.
          pbParallel.Value := 100;
          tmrUpdateProgress.Enabled := false;
          AfterTest;
        end
      ); //TThread.Queue
    end
  ); // TTask.Run
end;

procedure TfrmUpdateProgressBar.btnTThreadAsyncAwaitClick(Sender: TObject);
begin
  BeforeTest; //disable buttons

  AsyncAwaitTh(
    procedure
    begin
      Sleep(1000);
    end,
    procedure
    begin
      AfterTest; //enable buttons
    end);
end;

procedure TfrmUpdateProgressBar.CustomMessageHandler(const Sender: TObject;
  const M: TMessage);
begin
  // custom message
  pbParallel.Value := (M as TMyCustomMessage).Data;
end;

procedure TfrmUpdateProgressBar.FormCreate(Sender: TObject);
begin
  TMessageManager.DefaultManager.SubscribeToMessage(TMyCustomMessage, CustomMessageHandler);
end;

procedure TfrmUpdateProgressBar.FormDestroy(Sender: TObject);
begin
  TMessageManager.DefaultManager.Unsubscribe(TMyCustomMessage, CustomMessageHandler);
end;

procedure TfrmUpdateProgressBar.tmrUpdateProgressTimer(Sender: TObject);
begin
  if assigned(FParallelFor) then // OTL demo
    pbParallel.Value := Round(FProcessed.Value / FTotal * 100)
  else // PPL demo
    pbParallel.Value := Round(FProgress / FTotal * 100);
end;

end.
