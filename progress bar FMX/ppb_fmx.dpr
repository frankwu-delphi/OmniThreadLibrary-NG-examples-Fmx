program ppb_fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  ppb1 in 'ppb1.pas' {frmUpdateProgressBar};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmUpdateProgressBar, frmUpdateProgressBar);
  Application.Run;
end.
