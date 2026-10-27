program FolderScanner_Fmx;

uses
  System.StartUpCopy,
  FMX.Forms,
  fsMain in 'fsMain.pas' {frmFolderScanner};

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfrmFolderScanner, frmFolderScanner);
  Application.Run;
end.
