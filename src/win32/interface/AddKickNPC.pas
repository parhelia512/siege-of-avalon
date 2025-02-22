unit AddKickNPC;
(*
  Siege Of Avalon : Open Source Edition

  Portions created by Digital Tome L.P. Texas USA are
  Copyright �1999-2000 Digital Tome L.P. Texas USA
  All Rights Reserved.

  Portions created by Team SOAOS are
  Copyright (C) 2003 - Team SOAOS.

  Portions created by Steffen Nyeland are
  Copyright (C) 2019 - Steffen Nyeland.

  Contributor(s):
  Dominique Louis <Dominique@SavageSoftware.com.au>
  Steffen Nyeland

  You may retrieve the latest version of this file at:
  https://github.com/SteveNew/Siege-of-Avalon-Open-Source

  The contents of this file maybe used with permission, subject to
  the GNU Lesser General Public License Version 2.1 (the "License"); you may
  not use this file except in compliance with the License. You may
  obtain a copy of the License at https://opensource.org/licenses/LGPL-2.1

  Software distributed under the License is distributed on an "AS IS" basis,
  WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
  for the specific language governing rights and limitations under the License.

  Description:

  Requires: Delphi 10.3.3 or later

  Revision History:
  - 13 Jul 2003 - DL: Initial Upload to CVS
  - 10 Mar 2019 - SN: Forked on GitHub
  see git repo afterwards

*)

interface

uses
//  Winapi.DirectDraw,
  DirectX,
  System.Types,
  System.Classes,
  Vcl.Controls,
  Character,
  SoAOS.Intrface.Dialogs,
  SoAOS.Animation,
  MiscAI;

type
  TInforect = record
    rect : TRect;
    info : string;
    Enabled : boolean;
  end;

  TDrawTheGuyEvent = procedure( Character : TCharacter; X, Y : integer ) of object;

  TAIOptions = class( TObject )
  private
    AI : TCompanion;
    Image, Check : IDirectDrawSurface;
    CheckW, CheckH : integer;
    Offset : TPoint;
  public
    Region : TRect;
    CheckBox : array[ 0..7 ] of TRect;
    constructor Create( Character : TCharacter; AImage, DXCheck : IDirectDrawSurface; X, Y : integer; AOffset : TPoint );
    procedure Click( X, Y : integer );
    procedure Draw;
  end;

  TAddKickNPC = class( TDialog )
  strict private
    procedure CreateNPCRects(const NPCidx, CharX: Integer);
    procedure UpdateNPCRects(const NPCidx, CharX: Integer);
  private
    FOnDraw : TDrawTheGuyEvent;
    //Bitmap stuff
    DXBack : IDirectDrawSurface;
    DXBackToGame : IDirectDrawSurface;
    DXLeftGeeble : IDirectDrawSurface;
    DXRightGeeble : IDirectDrawSurface;
    DXBox : IDirectDrawSurface;
    DXBox2 : IDirectDrawSurface;
    SelectRect : array[ 0..20 ] of TInfoRect;
    txtMessage : array[ 0..23 ] of string;
    AIBoxList : TList;
    AIImage : IDirectDrawSurface;
    procedure ShowChars;
    procedure SetUpCollRects;
  protected
    procedure MouseDown( Sender : TObject; Button : TMouseButton;
      Shift : TShiftState; X, Y, GridX, GridY : Integer ); override;
    procedure MouseMove( Sender : TObject;
      Shift : TShiftState; X, Y, GridX, GridY : Integer ); override;
  public
    Character : TCharacter;
    //procedure DrawThem(Character: TCharacter; X,Y:integer);
    CheckBox : array[ 0..4 ] of Boolean;
    property OnDraw : TDrawTheGuyEvent read FOnDraw write FOnDraw;
    constructor Create;
    destructor Destroy; override;
    procedure Init; override;
    procedure Release; override;
  end;

implementation

uses
  System.SysUtils,
  DXUtil,
  DXEffects,
  SoAOS.Types,
  SoAOS.Graphics.Draw,
  SoAOS.Intrface.Text,
  SoAOS.AI,
  SoAOS.AI.Helper,
  Engine,
  Resource,
  Logfile,
  GameText,
  AniDemo;

{ TAddKickNPC }

constructor TAddKickNPC.Create;
const
  FailName : string = 'TAddKickNPC.Create';
begin
  Log.DebugLog(FailName);
  try

    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //Create

procedure TAddKickNPC.CreateNPCRects(const NPCidx, CharX: integer);
var
  VAdj1, vOffset, vOffAdj, cWidth : integer;
  NewAIBox : TAIOptions;
begin
  if NPCList.Count>=4 then // horizontal 4 member setup
  begin
   vAdj1 := -13;
   cWidth := 25;
   vOffAdj := 10;
  end
  else  // vertical 2 member setup
  begin
   vAdj1 := 107;
   cWidth := TResource( NPCList[ 0 ].Resource ).FrameWidth;
   vOffAdj := 0;
  end;

  if assigned( Character ) then //we are adding a char, so make room
    vOffset := 240
  else
    vOffset := 214 - TResource( NPCList[ 0 ].Resource ).FrameHeight div 2;

  Selectrect[ NPCidx ].rect := ApplyOffset( rect( CharX + 45, vOffset + VAdj1, CharX + 125, vOffset + VAdj1 + 20 ) );
  SelectRect[ NPCidx ].info := txtMessage[ 14 ] + NPCList[ NPCidx ].name + txtMessage[ 15 ];
  SelectRect[ NPCidx ].Enabled := true;
  if not assigned( Character ) then
  begin
    NewAIBox := TAIOptions.Create( NPCList[ NPCidx ], AIImage, DXBox2, CharX + cWidth + Offset.X, vOffset + vOffAdj + Offset.Y, Offset );
    AIBoxList.Add( NewAIBox );
  end;
end;

destructor TAddKickNPC.Destroy;
const
  FailName : string = 'TAddKickNPC.Destroy';
begin
  Log.DebugLog(FailName);
  try

    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //Destroy

procedure TAddKickNPC.Init;
var
  i, width, height : integer;
  DXBorder : IDirectDrawSurface;
  pr : TRect;
const
  FailName : string = 'TAddKickNPC.init';
begin
  Log.DebugLog(FailName);
  try

    if Loaded then
      Exit;
    inherited;
    MouseCursor.Cleanup;

    ExText.Open( 'AddKickNPC' );
    for i := 0 to 23 do
      txtMessage[ i ] := ExText.GetText( 'Message' + inttostr( i ) );

    for i := 0 to 4 do
    begin
      CheckBox[ i ] := false;
    end;

    pr := Rect( 0, 0, ResWidth, ResHeight );
    lpDDSBack.BltFast( 0, 0, lpDDSFront, @pr, DDBLTFAST_NOCOLORKEY or DDBLTFAST_WAIT );
    MouseCursor.PlotDirty := false;

    pText.LoadFontGraphic( 'inventory' ); //load the inventory font graphic in
    pText.LoadTinyFontGraphic;

    DXBox := SoAOS_DX_LoadBMP( InterfacePath + 'AddBox.bmp', cTransparent );
    DXBox2 := SoAOS_DX_LoadBMP( InterfacePath + 'AddBoxX.bmp', cTransparent );
    DXBackToGame := SoAOS_DX_LoadBMP( InterfaceLanguagePath + 'obInvBackToGame.bmp', cInvisColor );
    DXLeftGeeble := SoAOS_DX_LoadBMP( InterfacePath + 'LogLeftGeeble.bmp', cTransparent );
    DXRightGeeble := SoAOS_DX_LoadBMP( InterfacePath + 'LogRightGeeble.bmp', cTransparent );
    DXBack := SoAOS_DX_LoadBMP( InterfaceLanguagePath + 'LogScreen.bmp', cTransparent, DlgWidth, DlgHeight );

    DrawAlpha( DXBack, Rect( 0, 380, 213, 380 + 81 ), Rect( 0, 0, 213, 81 ), DXLeftGeeble, True, 60 );
    DrawAlpha( DXBack, Rect( 452, 0, 452 + 213, 81 ), Rect( 0, 0, 213, 81 ), DXRightGeeble, True, 60 );

    pr := Rect( 0, 0, DlgWidth, DlgHeight );
    lpDDSBack.BltFast( Offset.X, Offset.Y, DXBack, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );

  //Now for the Alpha'ed edges
    DXBorder := SoAOS_DX_LoadBMP( InterfacePath + 'obInvRightShadow.bmp', cInvisColor, width, height );
    DrawSub( lpDDSBack, ApplyOffset( Rect( 659, 0, 659 + width, height ) ), Rect( 0, 0, width, height ), DXBorder, True, 150 );
    DXBorder := nil;

    DXBorder := SoAOS_DX_LoadBMP( InterfacePath + 'obInvBottomShadow.bmp', cInvisColor, width, height );
    DrawSub( lpDDSBack, ApplyOffset( Rect( 0, 456, width, 456 + height ) ), Rect( 0, 0, width, height ), DXBorder, True, 150 );
    DXBorder := nil; //release DXBorder

    AIImage := SoAOS_DX_LoadBMP( InterfaceLanguagePath + 'CommandTree.bmp', cTransparent );

    DXLeftGeeble := nil;
    DXRightGeeble := nil;

    PlotText( txtMessage[ 0 ], 5, 5, 240 );
    if assigned( Character ) then
    begin
      PlotText( txtMessage[ 1 ], 30, 296, 240 );
      PlotText( txtMessage[ 2 ], 30, 316, 240 );

      PlotText( txtMessage[ 3 ], 400, 90, 240 );
      PlotText( txtMessage[ 4 ], 400, 110, 240 );
      PlotText( txtMessage[ 5 ], 400, 130, 240 );
    end
    else
    begin
      PlotText( txtMessage[ 1 ], 30, 196, 240 );
      PlotText( txtMessage[ 2 ], 30, 216, 240 );
    end;

    AIBoxList := TList.create;
    SetUpCollRects;
    ShowChars;

    SoAOS_DX_BltFront;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //Init


procedure TAddKickNPC.MouseDown( Sender : TObject; Button : TMouseButton;
      Shift : TShiftState; X, Y, GridX, GridY : Integer );
var
  i : integer;
  pr : TRect;
const
  FailName : string = 'TAddKickNPC.MouseDown';
begin
  Log.DebugLog(FailName);
  try
    if assigned( Character ) then
    begin
      if PtInRect( SelectRect[ 0 ].rect, point( X, Y ) ) then
      begin //add character
          //check to see if we already have a full party and are trying to add a new player
        if (NPCList.count=5) and (CheckBox[0]=false) and (CheckBox[1]=false) and (CheckBox[2]=false) and (CheckBox[3]=false) and (CheckBox[4]=false) then
        begin
          PlotTextBlock( txtMessage[ 6 ] + character.name + '.', 87, 590, 188, 240 );
        end
        else
        begin
          CheckBox[ 0 ] := not CheckBox[ 0 ];
              //clear center text line-but only if char assigned- otherwise we hit screen stuff
          if assigned( Character ) then
          begin
            pr := rect( 40, 174, 590, 245 );
            lpDDSBack.BltFast( 40 + Offset.X, 174 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
          end;
          ShowChars;
          SoAOS_DX_BltFront;
        end;
      end;
    end;

   //for i:=1 to NPCList.Count-1 do begin
    if NPCList.count > 1 then
    begin
      if PtInRect( SelectRect[ 1 ].rect, point( X, Y ) ) then
      begin
        if (NPCList.count=5) and (CheckBox[0]=true) and (CheckBox[1]=true) and (CheckBox[2]=false) and (CheckBox[3]=false) and (CheckBox[4]=false) then
        begin
          PlotTextBlock( txtMessage[ 7 ] + Character.name + txtMessage[ 8 ] + NPCList[ 1 ].name + txtMessage[ 9 ], 87, 590, 174, 240 );
        end
        else
        begin
          CheckBox[ 1 ] := not CheckBox[ 1 ];
            //clear center text line-but only if char assigned- otherwise we hit screen stuff
          if assigned( Character ) then
          begin
            pr := rect( 40, 174, 590, 245 );
            lpDDSBack.BltFast( 40 + Offset.X, 174 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
          end;
          ShowChars;
          SoAOS_DX_BltFront;
        end; //endif
      end; //end if
    end;
    if NPCList.count > 2 then
    begin
      if PtInRect( SelectRect[ 2 ].rect, point( X, Y ) ) then
      begin
        if assigned(Character) and (NPCList.count=5) and (CheckBox[0]=true) and (CheckBox[2]=true) and (CheckBox[1]=false) and (CheckBox[3]=false) and (CheckBox[4]=false) then
        begin
          PlotTextBlock( txtMessage[ 7 ] + Character.name + txtMessage[ 8 ] + NPCList[ 2 ].name + txtMessage[ 9 ], 87, 590, 174, 240 );
        end
        else
        begin
          CheckBox[ 2 ] := not CheckBox[ 2 ];
            //clear center text line-but only if char assigned- otherwise we hit screen stuff
          if assigned( Character ) then
          begin
            pr := Rect( 40, 174, 590, 245 );
            lpDDSBack.BltFast( 40 + Offset.X, 174 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
          end;
          ShowChars;
          SoAOS_DX_BltFront;
        end; //endif
      end; //end if
    end;
    if NPCList.count > 3 then
    begin
      if PtInRect( SelectRect[ 3 ].rect, point( X, Y ) ) then
      begin
        if assigned(Character) and (NPCList.count=5) and (CheckBox[0]=true) and (CheckBox[3]=true) and (CheckBox[2]=false) and (CheckBox[1]=false) and (CheckBox[4]=false) then
        begin
          PlotTextBlock( txtMessage[ 7 ] + Character.name + txtMessage[ 8 ] + NPCList[ 3 ].name + txtMessage[ 9 ], 87, 590, 174, 240 );
        end
        else
        begin
          CheckBox[ 3 ] := not CheckBox[ 3 ];
            //clear center text line-but only if char assigned- otherwise we hit screen stuff
          if assigned( Character ) then
          begin
            pr := Rect( 40, 174, 590, 245 );
            lpDDSBack.BltFast( 40 + Offset.X, 174 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
          end;
          ShowChars;
          SoAOS_DX_BltFront;
        end; //endif
      end; //end if
    end;
    if NPCList.count > 4 then
    begin
      if PtInRect( SelectRect[ 4 ].rect, point( X, Y ) ) then
      begin
        if assigned(Character) and (NPCList.count=5) and (CheckBox[0]=true) and (CheckBox[4]=true) and (CheckBox[2]=false) and (CheckBox[3]=false) and (CheckBox[1]=false) then
        begin
          PlotTextBlock( txtMessage[ 7 ] + Character.name + txtMessage[ 8 ] + NPCList[ 4 ].name + txtMessage[ 9 ], 87, 590, 174, 240 );
        end
        else
        begin
          CheckBox[ 4 ] := not CheckBox[ 4 ];
            //clear center text line-but only if char assigned- otherwise we hit screen stuff
          if assigned( Character ) then
          begin
            pr := Rect( 40, 174, 590, 245 );
            lpDDSBack.BltFast( 40 + Offset.X, 174 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
          end;
          ShowChars;
          SoAOS_DX_BltFront;
        end; //endif
      end; //end if
    end; //end if

    for i := 0 to AIBoxList.count - 1 do
    begin
      if PtInRect( ApplyOffset( TAIOptions( AIBoxList.items[ i ] ).Region ), point( X, Y ) ) then
      begin
        TAIOptions( AIBoxList.items[ i ] ).Click( X, Y );
        ShowChars;
        SoAOS_DX_BltFront;
        break;
      end;
    end;

    if PtinRect( ApplyOffset( rect( 588, 407, 588 + 77, 412 + 54 ) ), point( X, Y ) ) then //over back button
      Close;

  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //MouseDown

procedure TAddKickNPC.MouseMove( Sender : TObject;
      Shift : TShiftState; X, Y, GridX, GridY : Integer );
var
  i : integer;
  pr : TRect;
const
  FailName : string = 'TAddKickNPC.MouseMove';
begin
  Log.DebugLog(FailName);
  try
    pr := Rect( 588, 407, 588 + 77, 407 + 54 );
    lpDDSBack.BltFast( 588 + Offset.X, 407 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
    pr := Rect( 42, 388, 590, 460 );
    lpDDSBack.BltFast( 42 + Offset.X, 388 + Offset.Y, DXBack, @pr, DDBLTFAST_WAIT );
    if PtinRect( ApplyOffset( rect( 588, 407, 588 + 77, 412 + 54 ) ), point( X, Y ) ) then
    begin //over back button
      //plot highlighted back to game
      pr := Rect( 0, 0, 77, 54 );
      lpDDSBack.BltFast( 588 + Offset.X, 407 + Offset.Y, DXBackToGame, @pr, DDBLTFAST_WAIT );
    end;

    if assigned( Character ) then
    begin
      if PtInRect( SelectRect[ 0 ].rect, point( X, Y ) ) then
      begin
        PlotTextBlock( SelectRect[ 0 ].info, 122, 580, 410, 240 );
      end;
    end;

    for i := 1 to 20 do
    begin
      if SelectRect[ i ].Enabled and PtInRect( SelectRect[ i ].rect, point( X, Y ) ) then
      begin
        PlotTextBlock( SelectRect[ i ].info, 122, 580, 410, 240 );
      end;
    end;

    ShowChars;

    SoAOS_DX_BltFront;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;
end; //MouseMove


procedure TAddKickNPC.Release;
const
  FailName : string = 'TAddKickNPC.release';
var
  i : integer;
begin
  Log.DebugLog(FailName);
  try
    for i := 0 to AIBoxList.count - 1 do
      TObject( AIBoxList.items[ i ] ).free;
    AIBoxList.free;
    AIBoxList := nil;
    ExText.Close;
    AIImage := nil;
    DXBox := nil;
    DXBox2 := nil;
    pText.UnLoadTinyFontGraphic;
    DXBack := nil;
    DXBackToGame := nil;
    OnDraw := nil;
    Character := nil;
    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TAddKickNPC.ShowChars;
var
  Vadj1, Vadj2, vOffset, cOffset, CharX, cWidth : integer;
  i : integer;
  pr : TRect;
begin
  cOffset := 104;
  Vadj1 := 107;  // HD -120 ?? -13
  Vadj2 := 102;

  if assigned( Character ) then //we are adding a char, so make room
    vOffset := 240
  else
    vOffset := 214 - TResource( NPCList[ 0 ].resource ).FrameHeight div 2;

  cWidth := TResource( NPCList[ 0 ].resource ).FrameWidth;

//clear checkboxes
  if NPCList.count >3 then
  begin
    pr := Rect( 40, vOffset + VAdj1 - 120, 550, vOffset + VAdj1 - 100 );
    lpDDSBack.BltFast( 40 + Offset.X, vOffset + VAdj1 - 120 + Offset.Y, DXBack, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT)
  end
  else
  begin
    pr := Rect( 40, vOffset + VAdj1, 550, vOffset + VAdj1 + 24 );
    lpDDSBack.BltFast( 40 + Offset.X, vOffset + VAdj1 + Offset.Y, DXBack, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
  end;

  if assigned( character ) and assigned( OnDraw ) then
  begin
    CharX := cOffset + ( 463 div 2 ) - cWidth div 2;
    OnDraw( Character, CharX + Offset.X, vOffset - 200 + Offset.Y ); //guy to add
    i := pText.TinyTextLength( Character.name );
    PlotTinyText( Character.name, ( CharX + cWidth div 2 ) - ( i div 2 ), vOffset + 4 - 200, 240 );
    PlotTinyText( txtMessage[ 10 ], CharX + 65, vOffset - 200 + VAdj2, 240 );
    pr := Rect( CharX + 45, vOffset - 200 + VAdj1, CharX + 45 + 15, vOffset - 200 + VAdj1 + 15 );
    lpDDSBack.BltFast( CharX + 45 + Offset.X, vOffset - 200 + VAdj1 + Offset.Y, DXBack, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    pr := Rect( 0, 0, 15, 15 );
    if CheckBox[ 0 ] then
      lpDDSBack.BltFast( CharX + 45 + Offset.X, vOffset - 200 + VAdj1 + Offset.Y, DXBox2, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT )
    else
      lpDDSBack.BltFast( CharX + 45 + Offset.X, vOffset - 200 + VAdj1 + Offset.Y, DXBox, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
  end; //endif assigned

  if Assigned( OnDraw ) then
  begin
    if NPCList.count = 2 then
    begin
      CharX := cOffset + ( 463 div 5 ) * 2 - cWidth div 2;
      UpdateNPCRects(1, CharX);
    end
    else if NPCList.count = 3 then
    begin
      CharX := cOffset + ( 463 div 10 ) * 1 - cWidth div 2;
      UpdateNPCRects(1, CharX);
      CharX := cOffset + ( 463 div 7 ) * 5 - cWidth div 2;
      UpdateNPCRects(2, CharX);
    end
    else if NPCList.count = 4 then
    begin
      CharX := cOffset + ( 463 div 4 ) - cWidth div 2;
      UpdateNPCRects(1, CharX);
      CharX := cOffset + ( 463 div 2 ) - cWidth div 2;
      UpdateNPCRects(2, CharX);
      CharX := cOffset + ( 463 div 4 ) * 3 - cWidth div 2;
      UpdateNPCRects(3, CharX);
    end
    else if NPCList.count = 5 then
    begin
      cOffset := cOffset - 50;
      CharX := cOffset + ( 563 div 5 ) - cWidth div 2;
      UpdateNPCRects(1, CharX);
      CharX := cOffset + ( 563 div 5 ) * 2 - cWidth div 2;
      UpdateNPCRects(2, CharX);
      CharX := cOffset + ( 563 div 5 ) * 3 - cWidth div 2;
      UpdateNPCRects(3, CharX);
      CharX := cOffset + ( 563 div 5 ) * 4 - cWidth div 2;
      UpdateNPCRects(4, CharX);
    end;

    for i := 0 to AIBoxList.count - 1 do
    begin
      with TAIOptions( AIBoxList.items[ i ] ) do
      begin
        lpddsback.BltFast( Region.Left + Offset.X, Region.Top + Offset.Y, DXBack,
          @Region, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
        Draw;
      end;
    end;

  end; //endif
end;

procedure TAddKickNPC.UpdateNPCRects(const NPCidx, CharX: Integer);
var
  Vadj1, Vadj2, vOffset, vOffAdj, cWidth : integer;
  i : integer;
  pr : TRect;
begin
  if NPCList.Count>=4 then // horizontal 4 member setup
  begin
   vAdj1 := -13;
   vOffAdj := 128;
   vAdj2 := -18;
  end
  else  // vertical 2 member setup
  begin
   vAdj1 := 107;
   vOffAdj := 0;
   vAdj2 := 102;
  end;

  if assigned( Character ) then //we are adding a char, so make room
    vOffset := 240
  else
    vOffset := 214 - TResource( NPCList[ 0 ].resource ).FrameHeight div 2;

  cWidth := TResource( NPCList[ 0 ].resource ).FrameWidth;

  i := pText.TinyTextLength( NPCList[ NPCidx ].name );
  PlotTinyText( NPCList[ NPCidx ].name, ( CharX + cWidth div 2 ) - ( i div 2 ), vOffset - vOffAdj + 4, 240 );
  OnDraw( NPCList[ NPCidx ], CharX + Offset.X, vOffset - vOffAdj + Offset.Y );
  PlotTinyText( txtMessage[ 11 ], CharX + 65, vOffset + VAdj2, 240 );
  pr := Rect( 0, 0, 15, 15 );
  if CheckBox[ NPCidx ] then
    lpDDSBack.BltFast( CharX + 45 + Offset.X, vOffset + VAdj1 + Offset.Y, DXBox2, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT )
  else
    lpDDSBack.BltFast( CharX + 45 + Offset.X, vOffset + VAdj1 + Offset.Y, DXBox, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
end;

procedure TAddKickNPC.SetUpCollRects;
var
  cOffset, CharX, cWidth : integer;
  i, j, k : integer;
begin
  cOffset := 104;

  cWidth := TResource( NPCList[ 0 ].resource ).FrameWidth;
  if assigned( character ) then
  begin
    CharX := cOffset + ( 463 div 2 ) - cWidth div 2;
    Selectrect[ 0 ].rect := ApplyOffset( rect( CharX + 45, 142, CharX + 125, 142 + 20 ) );
    SelectRect[ 0 ].info := txtMessage[ 12 ] + Character.name + txtMessage[ 13 ];
    SelectRect[ 0 ].Enabled := true;
  end;

  if NPCList.count = 2 then
  begin
    CharX := cOffset + ( 463 div 5 ) * 2 - cWidth div 2;
    CreateNPCRects(1, CharX);
  end
  else if NPCList.count = 3 then
  begin
    CharX := cOffset + ( 463 div 10 ) * 1 - cWidth div 2;
    CreateNPCRects(1, CharX);
    CharX := cOffset + ( 463 div 7 ) * 5 - cWidth div 2;
    CreateNPCRects(2, CharX);
  end
  else if NPCList.count = 4 then
  begin
    CharX := cOffset + ( 463 div 4 ) - cWidth div 2;
    CreateNPCRects(1, CharX);
    CharX := cOffset + ( 463 div 2 ) - cWidth div 2;
    CreateNPCRects(2, CharX);
    CharX := cOffset + ( 463 div 4 ) * 3 - cWidth div 2;
    CreateNPCRects(3, CharX);
  end
  else if NPCList.count = 5 then
  begin
    cOffset := cOffset - 50;

    CharX := cOffset + ( 563 div 5 ) - cWidth div 2;
    CreateNPCRects(1, CharX);
    CharX := cOffset + ( 563 div 5 ) * 2 - cWidth div 2;
    CreateNPCRects(2, CharX);
    CharX := cOffset + ( 563 div 5 ) * 3 - cWidth div 2;
    CreateNPCRects(3, CharX);
    CharX := cOffset + ( 563 div 5 ) * 4 - cWidth div 2;
    CreateNPCRects(4, CharX);
  end;

  j := 5;
  for i := 0 to AIBoxList.count - 1 do
  begin
    if i > 1 then
      break;
    for k := 0 to 7 do
    begin
      with TAIOptions( AIBoxList.items[ i ] ) do
      begin
        Selectrect[ j ].rect := CheckBox[ k ];
        if NPCList.count = 5 then
          inc( Selectrect[ j ].rect.Right, 230 )
        else
          inc( Selectrect[ j ].rect.Right, 170 );
        SelectRect[ j ].info := txtMessage[ 16 + k ];
        SelectRect[ j ].Enabled := true;
        inc( j );
      end;
    end;
  end;

end; //SetUpCollRects

{ TAIOptions }

procedure TAIOptions.Click( X, Y : integer );
var
  i : integer;
begin
  if assigned( AI ) then
  begin
    for i := 0 to 7 do
    begin
      if PtInRect( CheckBox[ i ], Point( X, Y ) ) then
      begin
        case i of
          0 : AI.MeleeRanged := true;
          1 : AI.MeleeAggressive := true;
          2 : AI.MeleeDefensive := true;
          3 : AI.MagicAggressive := true;
          4 : AI.MagicDefensive := true;
          5 : AI.HoldAggressive := true;
          6 : AI.HoldDefensive := true;
          7 : AI.HoldandRun := true;
        end;
        break;
      end;
    end;
  end;
end;

constructor TAIOptions.Create( Character : TCharacter; AImage, DXCheck : IDirectDrawSurface; X, Y : integer; AOffset : TPoint );
var
  W, H : integer;
  i : integer;
begin
  inherited Create;
  if assigned( Character.AI ) and ( Character.AI is TCompanion ) then
    AI := TCompanion( Character.AI );
  Image := AImage; // CommandTree
  Check := DXCheck;
  Offset := AOffset;
  GetSurfaceDims( W, H, Image );
  Region.Left := X - Offset.X;
  Region.Top := Y - Offset.Y;
  Region.Right := X + W - Offset.X;
  Region.Bottom := Y + H - Offset.Y;

  CheckBox[ 0 ].TopLeft := Point( X + 1, Y + 21 );
  CheckBox[ 1 ].TopLeft := Point( X + 1, Y + 39 );
  CheckBox[ 2 ].TopLeft := Point( X + 1, Y + 57 );
  CheckBox[ 3 ].TopLeft := Point( X + 1, Y + 112 );
  CheckBox[ 4 ].TopLeft := Point( X + 1, Y + 129 );
  CheckBox[ 5 ].TopLeft := Point( X + 1, Y + 184 );
  CheckBox[ 6 ].TopLeft := Point( X + 1, Y + 202 );
  CheckBox[ 7 ].TopLeft := Point( X + 1, Y + 220 );
  GetSurfaceDims( CheckW, CheckH, Check );
  for i := 0 to 7 do
  begin
    CheckBox[ i ].Right := CheckBox[ i ].Left + CheckW;
    CheckBox[ i ].Bottom := CheckBox[ i ].Top + CheckH;
  end;
end;

procedure TAIOptions.Draw;
var
  pr : TRect;
begin
  // Clear checkbox
  pr := Rect( 0, 0, Region.Right - Region.Left, Region.Bottom - Region.Top );
  lpddsback.BltFast( Region.Left + Offset.X, Region.Top + Offset.Y, Image, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );

  if assigned( AI ) then
  begin
    pr := Rect( 0, 0, CheckW, CheckH );
    if AI.MeleeRanged then
      lpDDSBack.BltFast( CheckBox[ 0 ].Left, CheckBox[ 0 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.MeleeAggressive then
      lpDDSBack.BltFast( CheckBox[ 1 ].Left, CheckBox[ 1 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.MeleeDefensive then
      lpDDSBack.BltFast( CheckBox[ 2 ].Left, CheckBox[ 2 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.MagicAggressive then
      lpDDSBack.BltFast( CheckBox[ 3 ].Left, CheckBox[ 3 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.MagicDefensive then
      lpDDSBack.BltFast( CheckBox[ 4 ].Left, CheckBox[ 4 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.HoldAggressive then
      lpDDSBack.BltFast( CheckBox[ 5 ].Left, CheckBox[ 5 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.HoldDefensive then
      lpDDSBack.BltFast( CheckBox[ 6 ].Left, CheckBox[ 6 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
    if AI.HoldandRun then
      lpDDSBack.BltFast( CheckBox[ 7 ].Left, CheckBox[ 7 ].Top, Check, @pr, DDBLTFAST_SRCCOLORKEY or DDBLTFAST_WAIT );
  end;
end;

end.
