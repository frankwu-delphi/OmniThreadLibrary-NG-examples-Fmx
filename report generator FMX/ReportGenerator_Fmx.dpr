program ReportGenerator_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  reportGenerator1 in 'reportGenerator1.pas' {frmReportGenerator},
  ReportGeneratorEngine in 'ReportGeneratorEngine.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmReportGenerator, frmReportGenerator);
  Application.Run;
end.
