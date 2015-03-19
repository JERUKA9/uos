
program simplewebplayer;

{$IF DEFINED(Windows)}
WARNING => only for unix systems...
{$ENDIF}

{$mode objfpc}{$H+}
 {$DEFINE UseCThreads}

uses
  cmem, {$IFDEF UNIX} {$IFDEF UseCThreads}
  cthreads,
  cwstring, {$ENDIF} {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  main_wsp { you can add units after this };

{$R *.res}

begin
  Application.Title := 'SimpleWebPlayer';
  Application.Initialize;
  Application.CreateForm(TForm1, Form1);
  Application.Run;
end.


