unit uos_httpgetthread;

{This is HTTP Thread Getter done by
   Andrew Haines => andrewd207@aol.com }

{Modifications for uos done by
  Fred van Stappen => fiens@hotmail.com }

{$mode objfpc}{$H+}

interface

uses
 Classes, SysUtils,
 pipes;

type

  { TThreadHttpGetter }

  TThreadHttpGetter = class(TThread)
  private
    FWantedURL: String;
    FIsRunning: Boolean;
    FOutHandle: THandle;
    function GetRedirectURL(AResponseStrings: TStrings): String;
   protected
    procedure Execute; override;
   public
    InPipe: TInputPipeStream;
    FInHandle: THandle;
    PipeBufferSize : Cardinal;
    ReDirectURL: String ;
    constructor Create();
    procedure  WantedURL(AWantedURL: String);
    property IsRunning: Boolean read FIsRunning;
  end;

implementation
uses
  fphttpclient;

{ TThreadHttpGetter }

procedure TThreadHttpGetter.WantedURL(AWantedURL: String);
begin
   FWantedURL:=AWantedURL;
   FIsRunning:=True;
   Start;
end;

function TThreadHttpGetter.GetRedirectURL(AResponseStrings: TStrings): String;
var
  S: String;
  F: Integer;
  Search: String = 'location:';
begin
  Result := '';
  ReDirectURL := '';
  for S In AResponseStrings do
  begin
    WriteLn(S);
    F := Pos(Search, Lowercase(s));

    if F > 0 then
    begin
      Inc(F, Length(Search));
      Exit(Trim(Copy(S, F, Length(S)-F+1)));
    end;
  end;
end;

procedure TThreadHttpGetter.Execute;
var
  Http: TFPHTTPClient;
  OutPipe: TOutputPipeStream = nil;
  URL: String;
begin
  Http := TFPHTTPClient.Create(nil);
  OutPipe := TOutputPipeStream.Create(FOutHandle);

  URL := FWantedURL;
  repeat
  try
    Http.RequestHeaders.Clear;
     Http.Get(URL, OutPipe);

      writeln('===> Http.Get(URL,Output)') ;
  except
    on e: EHTTPClient do
    begin
      if Http.ResponseStatusCode = 302 then
      begin
        URL := GetRedirectURL(Http.ResponseHeaders);
        RedirectURL := RedirectURL + URL + ' ' ;
        writeln('===> Redirect URL: ' + RedirectURL) ;
        if URL <> '' then
          Continue;
      end
      else
      writeln('===> Http.Get(URL,Output) => error1') ;
       Break;
       // raise E;
    end
    else
    //  Raise;
     writeln('===> Http.Get(URL,Output) => error2') ;
     Break;
  end;
  Break;
  until False;

  try
    OutPipe.Free;
    Http.Free;
    writeln('===> Http.Free => ok') ;
  finally
   // make sure this is set to false when done
    FIsRunning:=False;
   InPipe.free;
  Destroy;
  end;
end;

constructor TThreadHttpGetter.Create();
begin
  inherited Create(True);
   FIsRunning:=False;
   PipeBufferSize  := $4000;
  CreatePipeHandles (FInHandle,FOutHandle, PipeBufferSize);
  InPipe := TInputPipeStream.Create(FInHandle);

 writeln('===> Input Handle = ' + inttostr(FInHandle) + ' Output Handle = ' + inttostr(FOutHandle));


end;

end.

