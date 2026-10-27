program StringListParser_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  StringListParser1 in 'StringListParser1.pas' {frmStringListParser};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmStringListParser, frmStringListParser);
  Application.Run;
end.
