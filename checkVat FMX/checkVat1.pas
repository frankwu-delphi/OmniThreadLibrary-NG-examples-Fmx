unit checkVat1;

interface

uses
  System.Messaging, System.SysUtils, System.Variants, System.Classes, FMX.Graphics,
  FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls, FMX.ExtCtrls, FMX.Memo,
  FMX.Types, System.Types, System.UITypes, FMX.Edit,   FMX.Memo.Types,
  FMX.ScrollBox, FMX.Controls.Presentation,

  checkVatService,
  OtlParallel;

type
  TfrmCheckVat = class(TForm)
    btnCheckVat: TButton;
    outVatInfo: TMemo;
    inpCC: TEdit;
    inpVat: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    procedure btnCheckVatClick(Sender: TObject);
  private
    FRequest: IOmniFuture<checkVatResponse>;
  private
  public
  end;

var
  frmCheckVat: TfrmCheckVat;

implementation

uses
  OtlTaskControl;

{$R *.fmx}

procedure TfrmCheckVat.btnCheckVatClick(Sender: TObject);
begin
  btnCheckVat.Enabled := false;
  outVatInfo.Lines.Clear;
  FRequest := Parallel.Future<checkVatResponse>(
    function: checkVatResponse
    var
      request: checkVat;
    begin
//      OleCheck(CoInitializeEx(nil, COINIT_MULTITHREADED));
      try
        request := checkVat.Create;
        try
          request.countryCode := Trim(inpCC.Text);
          request.vatNumber := Trim(inpVat.Text);
          Result := checkVatService.GetcheckVatPortType.checkVat(request);
        finally FreeAndNil(request); end;
      finally
//        CoUninitialize;
      end;
    end,
    Parallel.TaskConfig.OnTerminated(
      procedure (const task: IOmniTaskControl)
      begin
        outVatInfo.Text := FRequest.Value.name_ + #13#10 + FRequest.Value.address;
        FRequest.Value.Free;
        FRequest := nil;
        btnCheckVat.Enabled := true;
      end
    )
  );
end;

end.
