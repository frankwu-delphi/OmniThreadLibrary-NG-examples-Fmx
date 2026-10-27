program TThreadComm_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  tthreadCommMain in 'tthreadCommMain.pas' {frmTThreadComm};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmTThreadComm, frmTThreadComm);
  Application.Run;
end.
