program ForEachOutput_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  ForEachOutput1 in 'ForEachOutput1.pas' {frmForEachOutput};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmForEachOutput, frmForEachOutput);
  Application.Run;
end.
