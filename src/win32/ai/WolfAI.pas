unit WolfAI;
(*
  Siege Of Avalon : Open Source Edition

  Portions created by Digital Tome L.P. Texas USA are
  Copyright �1999-2000 Digital Tome L.P. Texas USA
  All Rights Reserved.

  Portions created by Team SOAOS are
  Copyright (C) 2003 - Team SOAOS.

  Portions created by Stefen Nyeland are
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
  - 10 Mar 2020 - SN: Forked on GitHub
  see git repo afterwards

*)

interface

uses
  Character,
  Anigrp30;

type
  TWolfType = ( wtWolf, wtStarving, wtDire, wtRabid );

  TWolfIdle = class( TAI )
  private
    Walking : Boolean;
    Leash : Integer;
    PercentageWounded : Integer;
    bCombative : Boolean;
    Delay : Integer;
    FWolfType : TWolfType;
    CenterX : Integer;
    CenterY : Integer;
    procedure RunAway;
    procedure FindTarget;
    procedure Meander;
    procedure Eat;
    //temp

  protected
    procedure OnStop; override;
    procedure OnNoPath; override;
    procedure WasAttacked( Source : TAniFigure; Damage : Single ); override;
    procedure WasKilled( Source : TAniFigure ); override;
  public
    procedure Init; override;
    property WolfType : TWolfType read FWolfType write FWolfType;
    procedure Follow( Source, Target : TAniFigure ); override;
    procedure Execute; override;
    function OnCollideFigure( Target : TAniFigure ) : boolean; override;
  end;

type
  TWolfCombat = class( TAI )
  private
    RunAwayTime : integer;
    Walking : Boolean;
    Delay : Integer;
    AttackDelay : integer;
    WolfType : string;
    PercentageWounded : Integer;
    CollideCount : Integer;
    bRunaway : Boolean;
    procedure Run;
    procedure FindTarget;
    procedure Attack;
    procedure Wait;
  protected
    procedure OnStop; override;
    procedure WasAttacked( Source : TAniFigure; Damage : Single ); override;
    procedure WasKilled( Source : TAniFigure ); override;
    procedure OnNoPath; override;
  public
    procedure Init; override;
    procedure Execute; override;
    procedure CallToArms( Source, Target : TAniFigure ); override;
    procedure Regroup( Source : TAniFigure; NewX, NewY : Integer ); override;
    procedure NotifyOfDeath( Source : TAniFigure ); override;
    function OnCollideFigure( Target : TAniFigure ) : boolean; override;
  end;

function AssignWolfAI( AIName : string ) : TAI;

implementation

uses
  System.Classes,
  System.SysUtils,
  System.Types,
  SoAOS.Types,
  AniDemo,
  LogFile,
  Resource;

function AssignWolfAI( AIName : string ) : TAI;
var
  S : string;
const
  FailName : string = 'AssignWolfAI';
begin
  Log.DebugLog( FailName );
  Result := nil;
  try
    S := LowerCase( AIName );

    if ( S = 'wolfidle' ) then
      Result := TWolfIdle.Create
    else if ( S = 'wolfcombat' ) then
      Result := TWolfCombat.Create
    else
      Result := nil;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

{ TWolfIdle }

procedure TWolfIdle.Execute;
const
  FailName : string = 'TWolfIdle.execute';
begin
  Log.DebugLog( FailName );
  try
    inherited;

    if bCombative then
      FindTarget;
    //watch for bad guys
    //if not Assigned(Character.Track) Or Runaway then
    // begin
    //if assigned(Dead) then Eat;

    if not walking then
    begin
      if Delay > 0 then
      begin
        dec( Delay );
        exit;
      end;
      case Random( 10 ) of
        0..7 :
            //Pick A random direction
          meander;
        8..9 :
          eat;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.Eat;
var
  List : TStringList;
const
  FailName : string = 'TWolfIdle.Eat';
begin
  Log.DebugLog( FailName );
  try
    List := GetPerceptibleDead( Character, 1.5 );
    if Assigned( List ) then
    begin
      if List.Count = 1 then
        Character.Track := TCharacter( List.Objects[ 0 ] )
      else
      begin
        Character.Track := TCharacter( List.Objects[ Random( List.Count ) ] );
        if Character.InRange( Character.Track ) then
        begin
          Walking := False;
          Character.Face( Character.Track.X, Character.Track.Y );
          Character.DoAction( 'Attack1' );
//                Character.Say('*Gnaw*', clWhite);
        end
        else
        begin
          Character.RunTo( Character.Track.X, Character.Track.Y, 64 );
                //Character.WalkTo(Character.Track.X, Character.Track.Y, 64);
          Walking := True;
        end;
        Delay := Random( 140 ) + 100;
        Character.Track := nil;
        List.free;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.meander;
var
  r : Integer;
  T : Single;
  X, Y : Integer;
const
  FailName : string = 'TWolfIdle.Meander';
begin
  Log.DebugLog( FailName );
  try
    Character.Track := nil;
    r := random( 500 );
    T := c2PI * random( 360 ) / 360;
    X := Round( r * cos( T ) ) + CenterX;
    Y := Round( r * sin( T ) ) + CenterY;
    Character.walkTo( X, Y, 16 );
    character.say( '...', cTalkBlackColor ); //clear text
    delay := Random( 200 ) + 200;
    Walking := True;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.RunAway;
const
  FailName : string = 'TWolfIdle.RunAway';
begin
  Log.DebugLog( FailName );
  try
    if assigned( Character.Track ) then
      Character.Face( Character.Track.X, Character.Track.Y );
    //Better runAway code
    if Pos( 'E', character.FacingString ) <> 0 then
      Character.RunTo( Character.X - 250, Character.Y + random( 500 ) - 250, 64 )
    else if Pos( 'W', character.FacingString ) <> 0 then
      Character.RunTo( Character.X + 250, Character.Y + random( 500 ) - 250, 64 )
    else if Pos( 'SS', character.FacingString ) <> 0 then
      Character.RunTo( Character.X + random( 500 ) - 250, Character.Y - 250, 64 )
    else
      Character.RunTo( Character.X + random( 500 ) - 250, Character.Y + 250, 64 );

    Walking := true;
    Delay := random( 240 );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.FindTarget;
var
  List : TStringList;
    //MostWounded: double;
    //iLoop: Integer;
    //Wounded: double;
const
  FailName : string = 'TWolfIdle.FindTarget';
begin
  Log.DebugLog( FailName );
  try
    if ( FrameCount mod 40 ) = 0 then
    begin
      List := GetPerceptibleEnemies( Character, 1.5 );
      if Assigned( List ) then
      begin
        if List.Count = 1 then
          Character.Track := TCharacter( List.objects[ 0 ] )
        else
          Character.Track := TCharacter( List.objects[ random( List.count ) ] );
        list.free;
        character.AIMode := aiCombat;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.Init;
var
  S : string;
const
  FailName : string = 'TWolfIdle.Init';
begin
  Log.DebugLog( FailName );
  try

    CenterX := Character.X;
    CenterY := Character.Y;
    TCharacterResource( character.Resource ).speed := 7;
    S := Character.Properties[ 'LeashLength' ];
    try
      if S = '' then
        Leash := 400
      else
        Leash := StrToInt( S );
    except
      Leash := 200;
    end;

    S := Lowercase( Character.Properties[ 'WolfType' ] );
    try
      if S = '' then
        WolfType := wtWolf
      else if S = 'wolf' then
        FWolfType := wtWolf
      else if S = 'starving' then
        FWolfType := wtStarving
      else if S = 'dire' then
        FWolfType := wtDire
      else if S = 'rabid' then
        FWolfType := wtRabid
      else
        FWolfType := wtWolf;
    except
      WolfType := wtWolf;
    end;

    S := LowerCase( Character.Properties[ 'Combative' ] );
    try
      if S = '' then
        bCombative := True
      else if S = 'false' then
        bCombative := False
      else
        bCombative := true;
    except
      bCombative := False;
    end;

    S := Character.Properties[ 'TimeToAttack' ];
    try
      if S = '' then
        PercentageWounded := 50
      else
        PercentageWounded := StrtoInt( S );
    except
      PercentageWounded := 50;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.Follow( Source, Target : TAnifigure );
const
  FailName : string = 'TWolfIdle.Follow';
begin
  Log.DebugLog( FailName );
  try
    character.WalkTo( Target.x, Target.Y, 16 );
    walking := True;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.OnNoPath;
const
  FailName : string = 'TWolfIdle.OnNoPath';
begin
  Log.DebugLog( FailName );
  try
    Walking := False;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.OnStop;
const
  FailName : string = 'TWolfIdle.OnStop';
begin
  Log.DebugLog( FailName );
  try
    Walking := False;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.WasAttacked( Source : TAniFigure; Damage : Single );
const
  FailName : string = 'TWolfIdle.WasAttacked';
begin
  Log.DebugLog( FailName );
  try
    inherited;
    if Source is TCharacter then
      character.Face( TCharacter( Source ).x, TCharacter( Source ).y );

    if bCombative then
    begin
      Character.Track := TCharacter( Source );
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

function TWolfIdle.OnCollideFigure( Target : TAniFigure ) : boolean;
const
  FailName : string = 'TWolfIdle.OnCollideFigure';
begin
  Log.DebugLog( FailName );
  Result := False;
  try
    if Target is TCharacter then
    begin
      if not Character.IsEnemy( TCharacter( Target ) ) then
      begin
        Character.Face( Target.x, Target.y );
        Character.Stand;
        Delay := Random( 160 );
      end
      else
      begin
        Character.Stand;
        Walking := False;
        if bCombative then
        begin
          if WolfType = wtStarving then
          begin
            if ( TCharacter( Target ).Wounds / TCharacter( Target ).HitPoints ) * 100 >= PercentageWounded then
              Character.Track := TCharacter( Target )
            else
            begin
              Character.Track := TCharacter( Target );
              Runaway;
            end;
          end
          else
            Character.Track := TCharacter( Target );
        end
        else
        begin
          Character.Track := TCharacter( Target );
          RunAway;
        end;
      end;
      Walking := false;
      Result := true;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfIdle.WasKilled( Source : TAniFigure );
const
  FailName : string = 'TWolfIdle.WasKilled';
begin
  Log.DebugLog( FailName );
  try
    if Source is TCharacter then
      character.Face( TCharacter( Source ).x, TCharacter( Source ).y );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

{ TWolfCombat }

procedure TWolfCombat.Execute;
const
  FailName : string = 'TWolfCombat.Execute';
begin
  Log.DebugLog( FailName );
  try

    inherited;
    if bRunaway then
      Run;
    if ( FrameCount mod 160 ) = 0 then
      walking := false;

    if not walking then
    begin
      if Delay > 0 then
      begin
        dec( Delay );
        exit;
      end;
    end;

    if Walking and Assigned( Character.Track ) then
    begin
      if ( frameCount mod 10 ) = 0 then
        if not ( Character.InRange( Character.Track ) ) then
          Character.RunTo( Character.Track.X, Character.Track.Y, 16 );
    end;

    if not Walking and Assigned( Character.Track ) then
      Attack
    else
      FindTarget;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.Run;
const
  FailName : string = 'TWolfCombat.Run';
begin
  Log.DebugLog( FailName );
  try

    if assigned( Character.Track ) then
    begin
      Character.Face( Character.Track.X, Character.Track.Y );
      Character.Track := nil;
    end;
    //Better runAway code
    if Pos( 'E', character.FacingString ) <> 0 then
      Character.RunTo( Character.X - 250, Character.Y + random( 500 ) - 250, 16 )
    else if Pos( 'W', character.FacingString ) <> 0 then
      Character.RunTo( Character.X + 250, Character.Y + random( 500 ) - 250, 16 )
    else if Pos( 'SS', character.FacingString ) <> 0 then
      Character.RunTo( Character.X + random( 500 ) - 250, Character.Y - 250, 16 )
    else
      Character.RunTo( Character.X + random( 500 ) - 250, Character.Y + 250, 16 );

    Walking := true;
    bRunaway := False;
    Delay := random( 240 );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.FindTarget;
var
  List : TStringList;
    //j: integer;
const
  FailName : string = 'TWolfCombat.FindTarget';
begin
  Log.DebugLog( FailName );
  try

    if ( FrameCount mod 40 ) = 0 then
    begin
      List := GetPerceptibleEnemies( Character, 1.5 );
      if assigned( List ) then
      begin
        if List.Count = 1 then
          Character.Track := TCharacter( List.objects[ 0 ] )
        else
          Character.Track := TCharacter( List.objects[ random( List.count ) ] );
        character.AIMode := aiCombat;
        list.free;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.Wait;
const
  FailName : string = 'TWolfCombat.Wait';
begin
  Log.DebugLog( FailName );
  try

    Character.WalkTo( Character.X + random( 80 ) - 40, Character.Y + random( 40 ) - 20, 16 );
    CollideCount := 0;
    Walking := true;
    Delay := random( 10 ) + 10;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.Attack;
const
  FailName : string = 'TWolfCombat.Attack';
begin
  Log.DebugLog( FailName );
  try
    if Character.Track is TCharacter and TCharacter( Character.Track ).Dead then
      Character.Track := nil
    else
    begin
      if Character.InRange( Character.Track ) then
      begin
        character.Face( Character.Track.x, Character.Track.y );
        Character.Attack( TCharacter( Character.Track ) );
        delay := ( AttackDelay - TCharacter( Character.Track ).Combat );
        if Delay < 0 then
          delay := 0;
        Walking := False;
      end
      else
      begin
        Character.RunTo( Character.Track.X, Character.Track.Y, 16 );
          //  Character.WalkTo(Character.Track.X,Character.Track.Y, 16);
        Walking := true;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.CallToArms( Source, Target : TAniFigure );
const
  FailName : string = 'TWolfCombat.Calltoarms';
begin
  Log.DebugLog( FailName );
  try

    Character.Track := TCharacter( Target );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.Regroup( Source : TAniFigure; NewX, NewY : Integer );
const
  FailName : string = 'TWolfCombat.Regroup';
begin
  Log.DebugLog( FailName );
  try

    Character.RunTo( NewX, NewY, 16 );
    Walking := true;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.Init;
var
  S : string;
  i : integer;
const
  FailName : string = 'TWolfCombat.Init';
begin
  Log.DebugLog( FailName );
  try

    TCharacterResource( character.Resource ).speed := 7;
    S := Character.Properties[ 'AttackDelay' ];
    try
      if ( S = '' ) or ( s = '0' ) then
        AttackDelay := 25
      else
        AttackDelay := StrToInt( S );
    except
      AttackDelay := 25;
    end;

    S := Character.Properties[ 'iSpeed' ];
    try
      if S <> '' then
        TCharacterResource( character.Resource ).Speed := StrToInt( S );
    except
    end;

    S := LowerCase( Character.Properties[ 'BalanceWithPlayer' ] );
    try
      if ( S <> '' ) and ( s <> '0' ) then
      begin
        i := StrToInt( s );
        if i >= 0 then
        begin

          //Addition: Because of higher resolution you can see opponents earlier, ranged attack without counterreaction
          if ScreenMetrics.ScreenWidth>800 then //TODO: Refactor like alot of other stuff - too much copy-paste everywhere
          begin
            if not Character.TitleExists('Widescreen') then
            begin
              Character.Vision := Character.Vision + 400;
              Character.AddTitle('Widescreen');
            end;
          end;
          // Addition

          character.Mysticism := player.Mysticism + i;
          character.Stealth := player.Stealth + i;
          character.combat := player.combat + i;
        end;
      end;
    except
    end;


    S := Character.Properties[ 'TimeToRun' ];
    try
      if S = '' then
        RunAwayTime := 75
      else
        RunAwayTime := StrToInt( S );
    except
      RunAwayTime := 75;
    end;

    S := Lowercase( Character.Properties[ 'WolfType' ] );
    try
      if S = '' then
        WolfType := 'dire'
      else
        WolfType := S;
    except
      WolfType := 'wolf';
    end;

    S := Character.Properties[ 'TimeToAttack' ];
    try
      if S = '' then
        PercentageWounded := 50
      else
        PercentageWounded := StrtoInt( S );
    except
      PercentageWounded := 50;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

function TWolfCombat.OnCollideFigure( Target : TAniFigure ) : boolean;
const
  FailName : string = 'TWolfCombat.onCollideFigure';
begin
  Log.DebugLog( FailName );
  Result := False;
  try

    if Target = Character.Track then
    begin
      Attack;
      Result := True;
    end
    else
    begin
      if Target is TCharacter then
      begin
        if Character.IsEnemy( TCharacter( Target ) ) then
        begin
          Character.Track := TCharacter( Target );
          Result := True;
        end
        else if assigned( Character.Track ) and not ( Character.InRange( Character.Track ) ) then
        begin
          inc( CollideCount );
          if ( CollideCount > 5 ) then
          begin
            Character.Stand;
            Wait;
            result := true;
          end;
        end;
      end;
    end;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.WasAttacked( Source : TAniFigure; Damage : single );
const
  FailName : string = 'TWolfCombat.WasAttacked';
begin
  Log.DebugLog( FailName );
  try

    if random( 6 ) = 0 then
      inherited;

    if Source is TCharacter then
      character.Face( TCharacter( Source ).x, TCharacter( Source ).y );

    if Source is TCharacter then
    begin
      if ( ( Character.Wounds / Character.HitPoints ) * 100 >= RunAwayTime ) and ( ( Character.Wounds / Character.HitPoints ) > ( TCharacter( Source ).Wounds / TCharacter( Source ).Hitpoints ) ) then
      begin
        Character.Track := TCharacter( Source );
        bRunAway := True;
      end
      else
      begin
        if ( Source is TCharacter ) and ( Character.Track = nil ) then
          if Character.IsEnemy( TCharacter( Source ) ) then
            Character.Track := TCharacter( Source );
      end;
    end;
    inherited;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.WasKilled( Source : TAniFigure );
const
  FailName : string = 'TWolfCombat.WasKilled';
begin
  Log.DebugLog( FailName );
  try

    if random( 3 ) = 0 then
      inherited;

    if Source is TCharacter then
      character.Face( TCharacter( Source ).x, TCharacter( Source ).y );
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.OnNoPath;
const
  FailName : string = 'TWolfCombat.OnNoPath';
begin
  Log.DebugLog( FailName );
  try

    Walking := False;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.OnStop;
const
  FailName : string = 'TWolfCombat.OnStop';
begin
  Log.DebugLog( FailName );
  try

    Walking := false;
  except
    on E : Exception do
      Log.log( FailName + E.Message );
  end;

end;

procedure TWolfCombat.NotifyOfDeath( Source : TAniFigure );
begin
end;

end.
