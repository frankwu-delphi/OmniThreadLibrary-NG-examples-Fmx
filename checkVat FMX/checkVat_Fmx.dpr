program checkVat_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  checkVat1 in 'checkVat1.pas' {frmCheckVat};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmCheckVat, frmCheckVat);
  Application.Run;
end.
