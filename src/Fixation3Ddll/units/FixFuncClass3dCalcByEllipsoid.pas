//****************************************************************************************************************************************************
//****************************************************************************************************************************************************
//***
//***
//***       FixFuncClass3dCalcByEllipsoidWP - Algoritmus zur Berechnung dreidimensionaler Fixationen mit Ellipsoid-R�ckgabeparametern
//***       =========================================================================================================================
//***
//***
//***       SW 17.09.2013
//***
//***       Berechnung einer 3D-Fixation anhand eines Ellipsoiden. Die Parameter des Ellipsoiden ergeben sich
//***       aus der Genauigkeit des Eyetrackingsystems und der Entfernung des aktuellen Zentrums. Bei Integration
//***       eines neuen Samples muss der Ellipsoid dreidimensional neu ausgerichtet werden. Zur Bestimmung eines
//***       Fluchtpunktes wird ein Zyklopenauge als Mittelwert der beiden Augenpositionen definiert.
//***
//***
//***


unit FixFuncClass3dCalcByEllipsoid;
interface
uses Windows, CodeSiteLogging;

type
  TFixFuncClass3dCalcByEllipsoidWP = class
  const
    RING_SIZE = 121;                    // *  Gr��e des Ringpuffers, in dem die berechneten Samples gespeichert werden.
                                        // *  Der Wert muss gr��er als die minimale Anzahl an Samples zur Erkennung einer Fixation iMinimumFixSamples sein.

                                        // *  Es werden 3 verschiedene Fixationen erfasst.
    NEW_FIX = 0;			                  // *  Neue Fixation
    PRES_FIX = 1;                       // *  Gegenw�rtige Fixation
    PREV_FIX = 2;                       // *  Vorangegangene Fixation

  Type

    _stFix = record 			              // *  Fixations-Datenstruktur
      iStartCount: Integer; 		        // *  Z�hlvariable zu DetectFixation() sobald die Fixation beginnt
      iEndCount: Integer; 		          // *  Z�hlvariable zu DetectFixation() sobald die Fixation endet.

      iNEyeFoundSamples: Integer; 	    // *  Anzahl g�ltiger GazePoint-Samples mit �eye-found�, so lange die Fixations-
                                        // *  Hypothese aufrecht erhalten bleibt.
                                        // * 	  Hinweis: 	Falls iNEyeFoundSamples 0 ist, existiert auch keine Fixations-
                                        // *		          Hypothese, z.B. wenn es keine Blickortdaten zur Unterst�tzung
                                        // * 		          der Hypothese mehr gibt.

      fXSum: Single; 			              // *  Addition zur Berechnung der Durchschnittswerte
      fYSum: Single; 	 		              // *  Die Summe wird zur Durchschnittsberechnung durch die Anzahl g�ltiger Samples iNEyeFoundSamples dividiert.
      fZSum: Single;

      fX: Single;  	  		              // *  Zentrum der Fixation
      fY: Single;   			              // *
      fZ: Single;

      fXEllipsoidR: Single;             // *  Parameter des Ellipsoidenzum bestimmt durch dessen letzte Ausrichtung der Fixation im 3D-Raum
      fYEllipsoidR: Single;
      fZEllipsoidR: Single;
      fEllipsoidYaw: Single;
      fEllipsoidPitch: Single;

      bFixationVerified: Integer; 	    // *  Flag, ob die Fixations-Hypothese best�tigt wurde
    end;

    _stRingBuf = record 		            // *  Ringpuffer zur Speicherung des letzen Blickortes und der Fixationsstatus-Werte:
      iDfCallCount: Integer; 		        // *  DetectFixation-Z�hlvariable zur Zeit des Samples

      bGazeFound: Integer; 		          // *  Flag, ob Blickort gefunden

      fXGaze: Single; 			            // *  Blickort-Koordinaten
      fYGaze: Single;
      fZGaze: Single;

      fXFix: Single; 			              // *  aktuelle Fixationskoordinaten � beinhaltet den aktuellen Blickort
      fYFix: Single;
      fZFix: Single;

      fXEllipsoidR: Single;             // *  Ausdehnung der Fixation bzw. des Ellipsoiden
      fYEllipsoidR: Single;
      fZEllipsoidR: Single;

                                        // *  Eulersche Winkel im Kartesischen Koordinatensystem zur Koordinatentransformation und Drehung der Fixation im Raum
      fEllipsoidYaw: Single;            // *  yaw angle (Rotation um die Y-Achse)
      fEllipsoidPitch: Single;          // *  pitch angle (Rotation um die X-Achse)

      iEyeMotionState: Integer; 	      // *  Status der Blickbewegung: 1=MOVING, 2=FIXATING, 3=FIXATION_COMPLETED

      iSacDuration: Integer; 		        // *  Sakkadendauer
      iFixDuration: Integer; 		        // *  Fixationsdauer
    end;

  private
    iDfCallCount: Integer;              // *  Z�hlvariable, wie oft DetectFixation() aufgerufen wurde, seitdem die Funktion
                                        // *  initialisiert wurde (60stel bzw. 120stel einer Sekunde, abh�ngig von der ET-
                                        // *  Sample Rate)

    iNOutsidePresEllipsoid: Integer;    // *  Anzahl fortlaufender Blickort-Samples au�erhalb des PRES_FIX-
                                        // *  Akzeptanzbereiches

    bGazeInPresFix: Integer;            // *  Befindet sich der Blickort in der aktuellen Fixation (1=in, 0=out)
    bGazeInNewFix:  Integer;            // *  Befindet sich der Blickort in der n�chsten Fixation  (1=in, 0=out)

    iMaxMissedSamples: Integer;         // *  Maximale Anzahl fehlender, fortlaufender Blickort-Samples, um die Fixation
                                        // *  fortf�hren zu k�nnen

    iMaxOutSamples: Integer; 		        // * Maximale Anzahl fehlender, fortlaufender Blickort-Samples, die au�erhalb des
                                        // * Akzeptanz-Bereiches liegen d�rfen

    stFix: array [0 .. 2] of _stFix;	  // neue, gegnw�rtige und vorangegangene Fixation
                                        // * NEW_FIX = 0
                                        // * PRES_FIX = 1
                                        // * PREV_FIX = 2

    stRingBuf: array [0 .. RING_SIZE] of _stRingBuf;

    iCurrentRingIndex: Integer;	        // * Ringindex des aktuellen Blickortsamples
    iRingIndexDelay: Integer;		        // * Ringindex des Blickortsamples von iMinimumFixSamples zuvor
    siPreviousFixEndCount: Integer;     // * Fixationsende der vorangeganenen Fixation

  protected
    procedure DeclarePresentFixationComplete(iMinimumFixSamples: Integer);
    procedure MoveNewFixToPresFix;
    procedure StartFixationHypothesisAtGazepoint(iNewPresOrPrev: Integer; fXGaze, fYGaze, fZGaze: Single);
    procedure TestPresentFixationHypothesis(iMinimumFixSamples: Integer);
    procedure TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples: Integer);
    procedure UpdateFixationHypothesis(iNewPresOrPrev: Integer;  fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad: Single; iMinimumFixSamples: Integer);
    procedure ResetFixationHypothesis(iNewPresOrPrev: Integer);

    procedure CalcEllipsoid(fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight, fXEllipsoidCenter, fYEllipsoidCenter, fZEllipsoidCenter, fAccuracyAngleRad: Single; var fXEllipsoidR, fYEllipsoidR, FZEllipsoidR, fEllipsoidYaw, fEllipsoidPitch: Single);
    function  IsGazeInFix(iNewPresOrPrev: Integer; fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight: Single; fXGaze, fYGaze, fZGaze: Single; fAccuracyAngleRad: Single): Integer;


  public
    ///////////////////////////////////////////////////////////////////////////////
    ///
    ///  SW: Global Output Parameters
    ///
    gb_stRingBuf: array [0 .. RING_SIZE] of _stRingBuf;
    gb_stFix: array [0 .. 2] of _stFix;


    procedure InitFixation(iMinimumFixSamples: Integer);

    function DetectFixation(  // INPUT
                              bGazepointFound: Integer;

                              fXLeftEye: Single;
                              fYLeftEye: Single;
                              fZLeftEye: Single;

                              fXRightEye: Single;
                              fYRightEye: Single;
                              fZRightEye: Single;

                        			fXGaze: Single;
      			                  fYGaze: Single;
                              fZGaze: Single;

                              fAccuracyAngleRad: Single;
                              iMinimumFixSamples: Integer;

                              // OUTPUT
                 out          pbGazepointFoundDelayed: Integer;

                 out          pfXGazeDelayed,
                              pfYGazeDelayed,
                              pfZGazeDelayed: Single;

                 out          pfXFixDelayed,
                              pfYFixDelayed,
                              pfZFixDelayed: Single;

                 out          pfXEllipsoidRDelayed,
                              pfYEllipsoidRDelayed,
                              pfZEllipsoidRDelayed: Single;

                 out          pfEllipsoidYawDelayed,
                              pfEllipsoidPitchDelayed: Single;

                 out          piSacDurationDelayed,
                              piFixDurationDelayed: Integer): Integer;
  end;
const

  MOVING = 0;
  FIXATING = 1;
  FIXATION_COMPLETED = 2;

implementation

uses
  SysUtils;

const
  FALSE = 0;
  TRUE = 1;



procedure TFixFuncClass3dCalcByEllipsoidWP.ResetFixationHypothesis(iNewPresOrPrev: Integer);
// * Zur�cksetzen der NewPresPrev-Fixation (abh�ngig vom �bergabe-Argument)

begin
  stFix[iNewPresOrPrev].iStartCount := 0;
  stFix[iNewPresOrPrev].iEndCount := 0;
  stFix[iNewPresOrPrev].iNEyeFoundSamples := 0; // 0 = Fixations-Hypothese existiert nicht mehr.
  stFix[iNewPresOrPrev].fXSum := 0;
  stFix[iNewPresOrPrev].fYSum := 0;
  stFix[iNewPresOrPrev].fZSum := 0;
  stFix[iNewPresOrPrev].fX := 0;
  stFix[iNewPresOrPrev].fY := 0;
  stFix[iNewPresOrPrev].fZ := 0;
  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fYEllipsoidR := 0;
  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fEllipsoidYaw := 0;
  stFix[iNewPresOrPrev].fEllipsoidPitch := 0;
  stFix[iNewPresOrPrev].bFixationVerified := FALSE;

  // * Falls die PRES-Fixation zur�ckgesetzt wird, muss auch die Anzahl aufeinander folgender Blickort-Samples
  // * au�erhalb des Fixations-Akzeptanz-Bereiches zur�ckgesetzt werden.
  if (iNewPresOrPrev = PRES_FIX) then
  begin
    iNOutsidePresEllipsoid := 0;
  end;
end;

function TFixFuncClass3dCalcByEllipsoidWP.IsGazeInFix(iNewPresOrPrev: Integer; fXEyeLeft, fYEyeLeft, fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight: Single; fXGaze, fYGaze, fZGaze: Single; fAccuracyAngleRad: Single): Integer;
// * Berechnung des Abstandes des Blickortes zum NewPresPrev-Fixationsort

var
    XEyeLeft,YEyeLeft,ZEyeLeft: Single;             // left eye position
    XEyeRight,YEyeRight,ZEyeRight: Single;          // right eye position
    XGaze,YGaze,ZGaze: Single;                      // gaze
    XFix,YFix,ZFix: Single;                         // fixation

    Alpha:    Single;                               // angle of accuracy in radians

    Psi, Theta: Single;                             // yaw and pitch angle between cyclops eye and current fixation

    deltaX,deltaY,deltaZ: Single;                   // deviation before ellipsoid rotation
    deltaXprime,deltaYprime,deltaZprime: Single;    // deviation after ellipsoid rotation

    XEllipsoidR,YEllipsoidR,ZEllipsoidR: Single;    // ellipsoid dimensions

    InEllipsoid: Single;                            // <=1 inside  the ellipsoid
                                                    // >1 outside the ellipsoid

begin
  // left Eye
  XEyeLeft:=fXEyeLeft;
  YEyeLeft:=fYEyeLeft;
  ZEyeLeft:=fZEyeLeft;

  // right Eye
  XEyeRight:=fXEyeRight;
  YEyeRight:=fYEyeRight;
  ZEyeRight:=fZEyeRight;

  // gaze
  XGaze:=fXGaze;
  YGaze:=fYGaze;
  ZGaze:=fZGaze;

  // accuracy angle
  Alpha:=fAccuracyAngleRad;
  //Alpha:=fAccuracyAngleRad/57.3;

  // fixation
  XFix := stFix[iNewPresOrPrev].fX;
  YFix := stFix[iNewPresOrPrev].fY;
  ZFix := stFix[iNewPresOrPrev].fZ;

  // deviations before rotation
  deltaX:=XGaze-XFix;
  deltaY:=YGaze-YFix;
  deltaZ:=ZGaze-ZFix;

  CalcEllipsoid(XEyeLeft,YEyeLeft,ZEyeLeft,XEyeRight,YEyeRight,ZEyeRight,XFix,YFix,ZFix,Alpha,XEllipsoidR,YEllipsoidR,ZEllipsoidR,Psi,Theta);

  // deviations after rotation
  deltaXprime:=deltaX*cos(Psi)+deltaZ*sin(Psi);
  deltaYprime:=deltaY*cos(Theta)+deltaZ*sin(Theta);
  deltaZprime:=deltaZ*cos(Theta)*cos(Psi)-deltaX*sin(Psi)-deltaY*sin(Theta);

  // Check if gaze is in ellipsoid
  InEllipsoid:=sqr(deltaXprime/XEllipsoidR)+sqr(deltaYprime/YEllipsoidR)+sqr(deltaZprime/ZEllipsoidR);

  if InEllipsoid<=1 then
    Result:=true
  else
    Result:=false;

end;



procedure TFixFuncClass3dCalcByEllipsoidWP.TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples: Integer);
// * Jedes Mal, wenn ein Blickort zur jetzigen Fixations-Hypothese hinzugef�gt wird, pr�ft die Funktion, ob die
// * Fixations-Hypothese best�tigt werden kann. Falls ja, updatet diese Funktion den Ringpuffer mit den entsprechenden Werten.

// * Zur Erinnerung: Der iEyeMoving-Wert im aktuellen Ringpuffer Index wurde mit �MOVING� initialisiert, zu
// * Beginn mit dem Aufruf der Funktion: DetectFixation()

var
  iRingPointOffset: Integer; 			  // * Ring-Index-Offset in Bezug auf den aktuellen Ring-Index
  iDumRingIndex: Integer; 			    // * Dummy Ring-Index
  iNFixSamples: Integer; 			      // * Anzahl der Samples innerhalb der Fixation bis jetzt
  iNNewSamples: Integer; 			      // * Anzahl neu hinzuzuf�gender Samples zur Ringpuffer Fixation

begin

  // * Falls die gegenw�rtige Fixations-Hypothese noch nicht �berpr�ft wurde, pr�fe die Hypothese jetzt.
  if (stFix[PRES_FIX].bFixationVerified = FALSE) then
  begin

    // * Falls gen�gend Samples zur Erkennung einer g�ltigen Fixation vorliegen �
    if (stFix[PRES_FIX].iNEyeFoundSamples >= iMinimumFixSamples) then
    begin
      // * Deklrariere die gegenw�rtige Fixation als best�tigt.
      stFix[PRES_FIX].bFixationVerified := TRUE;

      // * Markiere die Fixation innerhalb des Ringpuffers:
      // * F�ge alle Samples in den Ringpuffer ein, vom Start bis zum Endpunkt der PRES_Fixation:
      // * Berechne die Anzahl der Samples in der aktuellen Fixation, inklusive der guten Samples, der �no-track� Samples
      // * und auch der �out� Samples, die in die Fixation aufgenommen werden sollen.
      // * Beachte: +1 zur Ber�cksichtigung der beiden Start- und End-Samples.

      iNFixSamples := stFix[PRES_FIX].iEndCount - stFix[PRES_FIX].iStartCount + 1;

      // * Stelle sicher, dass die Anzahl der Samples nicht die Ringpuffer-Gr��e �berschreitet.
      Assert(iNFixSamples > 0);
      Assert(iNFixSamples <= RING_SIZE);
      if (iNFixSamples > RING_SIZE) then
        iNFixSamples := RING_SIZE;

      // * Gehe r�ckw�rts durch den Ringpuffer, beginnend mit dem aktuellen Ringindex, um die Anzahl der Fixations-
      // * Samples.
      for iRingPointOffset := 0 to iNFixSamples - 1 do
      begin
        // * Berechne den n�chsten Ringindex (r�ckw�rts).
        iDumRingIndex := iCurrentRingIndex - iRingPointOffset;
        if (iDumRingIndex < 0) then
          Inc(iDumRingIndex, RING_SIZE);
        Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

        // * Deklariere das Sample als �FIXATING� am aktuellen Fixationsort.
        stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
        stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
        stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
        stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;

        stRingBuf[iDumRingIndex].fXEllipsoidR := stFix[PRES_FIX].fXEllipsoidR;
        stRingBuf[iDumRingIndex].fYEllipsoidR := stFix[PRES_FIX].fYEllipsoidR;
        stRingBuf[iDumRingIndex].fZEllipsoidR := stFix[PRES_FIX].fZEllipsoidR;
        stRingBuf[iDumRingIndex].fEllipsoidYaw := stFix[PRES_FIX].fEllipsoidYaw;
        stRingBuf[iDumRingIndex].fEllipsoidPitch := stFix[PRES_FIX].fEllipsoidPitch;

        // * Setze den Ringpuffer-Eintrag f�r die Sakkadendauer, z.B. die Zeit zwischen Ende der
        // * letzten Fixation bis zum Start der gegenw�rtigen Fixation.
        // * Beachte: Die Sakkadendauer ist bei allen Samples dieser Fixation die gleiche.
        stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

        // * Setze den Ringpuffer-Eintrag f�r die Fixationsdauer, z.B. die Zeit zwischen
        // * Start der gegenw�rtigen Fixation und Zeit des Ringindexes.
        // * Beachte: Die Fixationsdauer �ndert sich! -> nimmt f�r fr�here gespeicherte Punkte ab

        stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iRingPointOffset - stFix[PRES_FIX].iStartCount + 1;
      end;

      // * Speichere das Fixationsende (Zahl) f�r den n�chsten Aufruf dieser Funktion.
      siPreviousFixEndCount := stFix[PRES_FIX].iEndCount;
    end

    // * Andererseits, wenn es nicht gen�gend gute Augensamples f�r die Erkennung einer Fixation gibt, �
    else // if (stFix[PRES_FIX].iNEyeFoundSamples < iMinimumFixSamples)
    begin
      // * � lasse den Ringpuffer unver�ndert.
    end
  end

  // * Andernerseits, falls die gegenw�rtige Fixationshypothese vorher best�tigt wurde �
  else 	// if (stFix[PRES_FIX].bFixationVerified == TRUE)
  begin
    // * Erweitere die Fixation innerhalb des Ringpuffers:
    // * Markiere alle neuen Samples im Ringpuffer ab dem letzten guten Sample, inklusive aller �missed�
    // * oder �out� Punkte als 'fixierend' bzw. FIXATING.
    // * Berechne die Anzahl neuer Samples seit  dem letzten guten Sample der aktuellen Fixation
    iNNewSamples := iDfCallCount - siPreviousFixEndCount;

    // * Stelle sicher, dass die Anzahl der Samples nicht die Ringpuffergr��e �bersteigt.
    Assert(iNNewSamples > 0);
    Assert(iNNewSamples <= RING_SIZE);
    if (iNNewSamples > RING_SIZE) then
      iNNewSamples := RING_SIZE;

     // * Gehe r�ckw�rts durch den Ringpuffer, beginnend mit dem aktuellen Ringindex, um die Anzahl der Fixations-
     // * Samples.
    for iRingPointOffset := 0 to iNNewSamples - 1 do
    begin
      // * Berechne den n�chsten Ringindex (r�ckw�rts).
      iDumRingIndex := iCurrentRingIndex - iRingPointOffset;
      if (iDumRingIndex < 0) then
        Inc(iDumRingIndex, RING_SIZE);

      Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

      // * Deklariere das Sample als �FIXATING� am aktuellen Fixationsort.
      stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
      stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
      stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
      stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;
      stRingBuf[iDumRingIndex].fXEllipsoidR := stFix[PRES_FIX].fXEllipsoidR;

      stRingBuf[iDumRingIndex].fYEllipsoidR := stFix[PRES_FIX].fYEllipsoidR;
      stRingBuf[iDumRingIndex].fZEllipsoidR := stFix[PRES_FIX].fZEllipsoidR;
      stRingBuf[iDumRingIndex].fEllipsoidYaw := stFix[PRES_FIX].fEllipsoidYaw;
      stRingBuf[iDumRingIndex].fEllipsoidPitch := stFix[PRES_FIX].fEllipsoidPitch;

      // * Setze den Ringpuffer-Eintrag f�r die Sakkadendauer, z.B. die Zeit zwischen Ende der
      // * letzten Fixation bis zum Start der gegenw�rtigen Fixation.
      // * Beachte: Die Sakkadendauer ist bei allen Samples dieser Fixation die gleiche.
      stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

      // * Setze den Ringpuffer-Eintrag f�r die Fixationsdauer, z.B. die Zeit zwischen
      // * Start der gegenw�rtigen Fixation und Zeit des Ringindexes.
      // * Beachte: Die Fixationsdauer �ndert sich! -> nimmt f�r fr�here gespeicherte Punkte ab
      stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iRingPointOffset - stFix[PRES_FIX].iStartCount + 1;
    end;

    // * Speichere das Fixationsende (Zahl) f�r den n�chsten Aufruf dieser Funktion.
    siPreviousFixEndCount := stFix[PRES_FIX].iEndCount;
  end;
end;



procedure TFixFuncClass3dCalcByEllipsoidWP.UpdateFixationHypothesis(iNewPresOrPrev: Integer;  fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad: Single; iMinimumFixSamples: Integer);
// * Diese Funktion erweitert die iNewPresOrPrev-Fixation um einen neuen Blickort -> beides �bergabeparameter
// * und pr�ft, ob genug Samples vorhanden sind, um zu erkennen, dass das Auge in diesem Moment fixiert.
// * Falls dem so ist, deklariere die betreffenden Ringpuffereintr�ge als zur Fixation zugeh�rig.
// * Die Funktion stellt auch sicher, dass es keine Hypothese f�r eine neue Fixation gibt.

begin
  // * Erweiterung der Fixation um den neuen Blickpunkt.
  Inc(stFix[iNewPresOrPrev].iNEyeFoundSamples);
  stFix[iNewPresOrPrev].fXSum := stFix[iNewPresOrPrev].fXSum + fXGaze;
  stFix[iNewPresOrPrev].fYSum := stFix[iNewPresOrPrev].fYSum + fYGaze;
  stFix[iNewPresOrPrev].fZSum := stFix[iNewPresOrPrev].fZSum + fZGaze;
  stFix[iNewPresOrPrev].fX := stFix[iNewPresOrPrev].fXSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].fY := stFix[iNewPresOrPrev].fYSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].fZ := stFix[iNewPresOrPrev].fZSum / stFix[iNewPresOrPrev].iNEyeFoundSamples;
  stFix[iNewPresOrPrev].iEndCount := iDfCallCount;


  // * Berechnung der neuen Ellipsoidenparameter
  CalcEllipsoid(fXLeftEye,fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye,stFix[iNewPresOrPrev].fX, stFix[iNewPresOrPrev].fY, stFix[iNewPresOrPrev].fZ, fAccuracyAngleRad, stFix[iNewPresOrPrev].fXEllipsoidR, stFix[iNewPresOrPrev].fYEllipsoidR, stFix[iNewPresOrPrev].fZEllipsoidR, stFix[iNewPresOrPrev].fEllipsoidYaw, stFix[iNewPresOrPrev].fEllipsoidPitch);

  // * Falls es sich um die gegenw�rtige Fixation handelt, �
  if (iNewPresOrPrev = PRES_FIX) then
  begin

    // * � l�sche die Anzahl aufeinanderfolgender Blickpunkte, die au�erhalb des aktuellen
    // * Fixations-Akzeptanzbereiches lagen.
    iNOutsidePresEllipsoid := 0;

    // * Teste, ob es genug Samples in der gegenw�rtigen Fixations-Hypothese zur Erkennung einer Fixation gibt.
    // * Falls dem so ist, deklariere die betreffenden Ringpuffereintr�ge als zur Fixation zugeh�rig.
    TestPresFixHypAndUpdateRingBuffer(iMinimumFixSamples);

    // * Stelle sicher, dass es keine Hypothese f�r eine neue Fixation gibt.
    ResetFixationHypothesis(NEW_FIX);

  end;
end;


procedure TFixFuncClass3dCalcByEllipsoidWP.StartFixationHypothesisAtGazepoint(iNewPresOrPrev: Integer; fXGaze, fYGaze, fZGaze: Single);
// * Diese Funktion startet die Fixation (NewPresPrev) am Blickort (beides �bergabewerte) und stellt sicher,
// * dass es keine neue Fixations-Hypothese gibt.

begin
  // * Starte die Fixation am Blickort.
  stFix[iNewPresOrPrev].iNEyeFoundSamples := 1;
  stFix[iNewPresOrPrev].fXSum := fXGaze;
  stFix[iNewPresOrPrev].fYSum := fYGaze;
  stFix[iNewPresOrPrev].fZSum := fZGaze;
  stFix[iNewPresOrPrev].fX := fXGaze;
  stFix[iNewPresOrPrev].fY := fYGaze;
  stFix[iNewPresOrPrev].fZ := fZGaze;

  stFix[iNewPresOrPrev].fXEllipsoidR := 0;
  stFix[iNewPresOrPrev].fYEllipsoidR := 0;
  stFix[iNewPresOrPrev].fZEllipsoidR := 0;

  stFix[iNewPresOrPrev].fEllipsoidYaw := 0;    // *  Normalerweise kann man an dieser Stelle bereits die Winkel f�r den ersten Punkt berechnen,
  stFix[iNewPresOrPrev].fEllipsoidPitch := 0;  // *  jedoch wird dieser mit UpdateFixationHypotheses sowieso durchgef�hrt.

  stFix[iNewPresOrPrev].iStartCount := iDfCallCount;
  stFix[iNewPresOrPrev].iEndCount := iDfCallCount;
  stFix[iNewPresOrPrev].bFixationVerified := FALSE;

  // * Falls es sich um die gegenw�rtige Fixation handelt �
  if (iNewPresOrPrev = PRES_FIX) then
  begin
    // * � l�sche die Anzahl aufeinanderfolgender Blickpunkte, die au�erhalb des aktuellen
    // * Fixations-Akzeptanzbereiches lagen.
    iNOutsidePresEllipsoid := 0;

    // *    Stelle sicher, dass es keine Hypothese f�r eine neue Fixation gibt.
    ResetFixationHypothesis(NEW_FIX);
  end;
end;



procedure TFixFuncClass3dCalcByEllipsoidWP.MoveNewFixToPresFix;
// * Diese Funktion kopiert die neuen Fixationsdaten in die gegenw�rtige Fixation und l�scht die neue Fixations-Hypothese

begin
   // * L�sche die Anzahl aufeinanderfolgender Blickpunkte, die au�erhalb des aktuellen
   // * Fixations-Akzeptanzbereiches liegen.
   iNOutsidePresEllipsoid := 0;

   // * Macht die neue Fixations-Hypothese zur gegenw�rtigen Fixations-Hypothese.
   stFix[PRES_FIX] := stFix[NEW_FIX];

   // * L�scht NEW_FIX.
   ResetFixationHypothesis(NEW_FIX);
end;


procedure TFixFuncClass3dCalcByEllipsoidWP.CalcEllipsoid(fXEyeLeft, fYEyeLeft,
  fZEyeLeft, fXEyeRight, fYEyeRight, fZEyeRight, fXEllipsoidCenter, fYEllipsoidCenter, fZEllipsoidCenter,
  fAccuracyAngleRad: Single; var fXEllipsoidR, fYEllipsoidR, FZEllipsoidR, fEllipsoidYaw, fEllipsoidPitch: Single);

var
    XCycl,YCycl,ZCycl: Single;                 // cyclops eye

    D: Single;              // distance between the eyes
    R: Single;              // distance between cyclops eye and current fixation

begin
   // define a cyclops eye
  XCycl:=round((fXEyeLeft+fXEyeRight)/2);
  YCycl:=round((fYEyeLeft+fYEyeRight)/2);
  ZCycl:=round((fZEyeLeft+fZEyeRight)/2);


  // distance between eyes
  D:=round(sqrt(sqr(fXEyeLeft-fXEyeRight)+sqr(fYEyeLeft-fYEyeRight)+sqr(fZEyeLeft-fZEyeRight)));

  // distance between cyclops eye and current fixation
  R:=round(sqrt(sqr(XCycl-fXEllipsoidCenter)+sqr(YCycl-fYEllipsoidCenter)+sqr(ZCycl-fZEllipsoidCenter)));


  // ellipsoid parameters based on the accuracy and distance between eyes and fixation
  fXEllipsoidR:=R*fAccuracyAngleRad;
  fYEllipsoidR:=R*fAccuracyAngleRad;
  FZEllipsoidR:=fXEllipsoidR*(R/D);

  fEllipsoidYaw:=+arctan((fXEllipsoidCenter-XCycl)/(fZEllipsoidCenter-ZCycl));      // yaw angle, psi is positive when the person looks left
  fEllipsoidPitch:=-arctan((fYEllipsoidCenter-YCycl)/(fZEllipsoidCenter-ZCycl));    // pitch angle, theta is positive when the person looks up

end;

procedure TFixFuncClass3dCalcByEllipsoidWP.DeclarePresentFixationComplete(iMinimumFixSamples:Integer);
// * Diese Funktion:
// * 	a) erkl�rt die aktuelle Fixation f�r beendet bei stFix[PRES_FIX].iEndCount.
// * 	b) macht die gegenw�rtige Fixation zur vorhergehenden Fixation und
// * 	c) macht die neue Fixation, falls vorhanden zur gegenw�rtigen Fixation.

var
  iRingIndexLastFixSample:Integer;	//* Ringindex des letzten Samples der gegenw�rtigen kompletten Fixation
  iDoneNSamplesAgo:Integer;

begin
   //* Berechne wie viele Samples vorher die Fixation beendet war.
   iDoneNSamplesAgo := iDFCallCount - stFix[PRES_FIX].iEndCount;

   Assert(iDoneNSamplesAgo <= iMinimumFixSamples);
   if (iDoneNSamplesAgo > iMinimumFixSamples) then
       iDoneNSamplesAgo := iMinimumFixSamples;

   //* Berechne den Ringindex, der korrespondierend mit der zugeh�rigen Fertigstellungszeit der Fixation.
   iRingIndexLastFixSample := iCurrentRingIndex - iDoneNSamplesAgo;
   if (iRingIndexLastFixSample < 0) then
       Inc(iRingIndexLastFixSample, RING_SIZE);

   Assert(iRingIndexLastFixSample >= 0);
   Assert(iRingIndexLastFixSample < RING_SIZE);

   //*  Erkl�re die gegenw�rtige Fixation f�r beendet.
   stRingBuf[iRingIndexLastFixSample].iEyeMotionState := FIXATION_COMPLETED;

   //* Mach die gegenw�rtige Fixation zur vorhergehenden Fixation
   stFix[PREV_FIX] := stFix[PRES_FIX];

   //* Mache die Daten der neuen Fixation, falls vorhanden, zur gegenw�rtigen Fixation, l�sche die neue Fixation
   //* und pr�fe, ob es genug Samples in der neuen Fixation (jetzt die gegenw�rtige) gibt, um zu pr�fen, ob das Auge
   //* aktuell fixiert.
   MoveNewFixToPresFix();
end;


procedure TFixFuncClass3dCalcByEllipsoidWP.InitFixation(iMinimumFixSamples: Integer);
// * iMinimumFixSamples = Minimale Anzahl an Gaze Samples zur Bestimmung einer Fixation
// * Beachte: Falls der Eingabewert kleiner 3 ist, wird dieser auf 3 gesetzt.

// * InitFixation() sollte vor DetectFixation() aufgerufen werden.

begin
  // * Setze die maximal m�gliche Anzahl aufeinanderfolgender Samples,
  // * die innerhalb einer Fixation �ungetrackt� bleiben d�rfen.
  iMaxMissedSamples := 3;

  // * Setze die maximal m�gliche Anzahl aufeinanderfolgender Samples,
  // * die au�erhalb des Fixations-Akzeptanzbereiches liegen d�rfen.
  iMaxOutSamples := 1;

  // * Initialisiere den internen Ringpuffer
  iCurrentRingIndex := 0;
  while iCurrentRingIndex < RING_SIZE do

  begin
    stRingBuf[iCurrentRingIndex].iDfCallCount := 0;
    stRingBuf[iCurrentRingIndex].bGazeFound := FALSE;

    stRingBuf[iCurrentRingIndex].fXGaze := 0;
    stRingBuf[iCurrentRingIndex].fYGaze := 0;
    stRingBuf[iCurrentRingIndex].fZGaze := 0;

    stRingBuf[iCurrentRingIndex].fXFix := 0;
    stRingBuf[iCurrentRingIndex].fYFix := 0;
    stRingBuf[iCurrentRingIndex].fZFix := 0;

    stRingBuf[iCurrentRingIndex].fXEllipsoidR := 0;
    stRingBuf[iCurrentRingIndex].fYEllipsoidR := 0;
    stRingBuf[iCurrentRingIndex].fZEllipsoidR := 0;

    stRingBuf[iCurrentRingIndex].fEllipsoidYaw := 0;
    stRingBuf[iCurrentRingIndex].fEllipsoidPitch := 0;


//    stRingBuf[iCurrentRingIndex].fGazeDeviation := -0.1;

    stRingBuf[iCurrentRingIndex].iEyeMotionState := MOVING;
    stRingBuf[iCurrentRingIndex].iSacDuration := 0;
    stRingBuf[iCurrentRingIndex].iFixDuration := 0;
    Inc(iCurrentRingIndex);
  end;
  iCurrentRingIndex := 0;
  iRingIndexDelay := RING_SIZE - iMinimumFixSamples;

  // * Setze die Anzahl der Aufrufe von DetectFixation() seit Initialisierung auf 0 und
  // * initialisiere die Z�hlvariable f�r das vorhergehende Fixationsende.
  // * Dadurch wird die erste Sakkadendauer  eine legitime Zahl.
  iDfCallCount := 0;
  stFix[PREV_FIX].iEndCount := 0;

  // * L�sche die gegenw�rtigen Fixationsdaten.
  ResetFixationHypothesis(PRES_FIX);

  // * L�sche die neuen Fixationsdaten.
  ResetFixationHypothesis(NEW_FIX);
end;



function TFixFuncClass3dCalcByEllipsoidWP.DetectFixation(

                                          // * INPUT PARAMETER:
                                          bGazepointFound: Integer; 		      // *  Indikator, ob der bildverarbeitende Algorithmus gefunden und damit
                                                                              // *  einen g�ltigen Blickpunkt berechnet hat oder nicht  (TRUE/FALSE)
                                          fXLeftEye: Single;                  // *  Koordinaten linkes Auge
                                          fYLeftEye: Single;
                                          fZLeftEye: Single;

                                          fXRightEye: Single;                 // *  Koordinaten rechtes Auge
                                          fYRightEye: Single;
                                          fZRightEye: Single;

                                          fXGaze: Single; 				            // *  aktueller Blickort
                                          fYGaze: Single;
                                          fZGaze: Single;

                                          fAccuracyAngleRad: Single;          // *  Genauigkeit des Eyetracking Systems

                                          iMinimumFixSamples: Integer; 		    // *  minimale Anzahl an Gaze Samples, um eine Fixation zu erkennen.
                                                                              // *  Beachte: Falls dieser Wert mit weniger als 3 betr�gt,
                                                                              // * 	         wird er automatisch auf 3 gesetzt.


                                          // * OUTPUT PARAMETER: Verz�gerte Blickortdaten mit Fixationsparametern

                           out            pbGazepointFoundDelayed: Integer;   // * Indikator, ob ein Sample iMinimumFixSamples zuvor gefunden wurde.

                           out            pfXGazeDelayed,  		                // * Blickortkoordinaten - iMinimumFixSamples vorher
                                          pfYGazeDelayed,
                                          pfZGazeDelayed: Single;

                                          // * Fixationsdaten - verz�gert:
                           out            pfXFixDelayed, 			                // * gesch�tzter Fixationsort - iMinimumFixSamples vorher
                                          pfYFixDelayed,
                                          pfZFixDelayed: Single;

                           out            pfXEllipsoidRDelayed,               // * Ausdehnung der Fixation bzw. des Ellipsoiden
                                          pfYEllipsoidRDelayed,
                                          pfZEllipsoidRDelayed: Single;

                                                                              // *  Eulersche Winkel im Kartesischen Koordinatensystem zur Koordinatentransformation und Drehung der Fixation im Raum
                           out            pfEllipsoidYawDelayed,              // *  yaw angle (Rotation der Fixation um die Y-Achse)
                                          pfEllipsoidPitchDelayed: Single;    // *  pitch angle (Rotation der Fixation um die X-Achse)

                           out            piSacDurationDelayed, 	            // * Dauer der Sakkade, die der gegenw�rtigen Fixation voranging (Samples)
                                          piFixDurationDelayed: Integer): Integer; 	// * Dauer der gegenw�rtigen Fixation (Samples)

// *  R�ckgabewerte - Eye Motion State:
// *
// *    MOVING			          0   Das Auge war in Bewegung, iMinimumFixSamples vorher.
// *    FIXATING			        1   Das Auge fixierte, iMinimumFixSamples vorher.
// *    FIXATION_COMPLETED   	2   Eine abgeschlossene Fixation wurde erkannt, iMinimumFixSamples vorher.
// *
// *	In Bezug auf das Sample, welches FIXATION_COMPLETED zur�ck gibt, startete die Fixation
// *	(iMinimumFixSamples + *piSaccadeDurationDelayed) vorher und endete iMinimumFixSamples vorher.
// *
// *	Beachte:  Dadurch, dass es eine Mess-Verz�gerung anhand der Bildverarbeitungsprozesse gibt (ca. 2-Samples),
// *            m�ssen die Start- und Endzeit in Bezug zur Echtzeit korrigiert werden.
// *
// *	Startzeit:  iMinimumFixSamples + *piSaccadeDurationDelayed + 2
// *	Endzeit: 	  iMinimumFixSamples + 2
// *
// *
// *  Zusammenfassung
// *  ===============
// *
// *  Diese Funktion konvertiert eine Serie gleichm��ig abgetasteter Blickpunkte in eine Serie von Sakkaden und Fixationen
// *  variabler Dauer.
// *
// *  Die Fixationserkennung kann in Echtzeit oder auch nachtr�glich erfolgen. Um die Fixationserkennung w�hrend der
// *  Blickdatenaufzeichnung (Echtzeit) durchf�hren zu k�nnen, muss diese Funktion f�r jedes Sample aufgerufen werden.
// *
// *  Falls das Auge in Bewegung ist, z.B. w�hrend einer Sakkade, gibt diese Funktion 0 (MOVING) zur�ck.
// *  Falls das Auge stillsteht, z.B. w�hrend einer Fixation gibt die Funktion 1 (FIXATING)  zur�ck.
// *  Falls eine abgeschlossene Fixation erkannt wird, gibt die Funktion 2 (FIXATION_COMPLETED) mit folgenden
// *  Parametern zur�ck:
// *
// *  	a) Die Sakkadendauer zwischen der letzten und gegenw�rtigen Fixation (eyegaze samples)
// *  	b) Die Dauer der gegenw�rtigen, jetzt abgeschlossenen Fixation
// *  	c) Die durchschnittlichen x- und y- Koordinaten der Fixation
// *
// *  Beachte: Obwohl diese Funktion  in Echtzeit arbeitet, gibt es eine Verz�gerung von iMinimumFixSamples im Filter,
// *  welcher die Bewegung/Fixation des Auges erkennt.
// *
// *
// *  PRINZIP DES 3D-ALGORITHMUS
// *  ==========================
// *
// *  Diese Funktion erkennt Fixationen mittels Suche nach Sequenzen gemessener Blickorte, die relativ konstant sind bzw.
// *  am selben Ort verharren. Falls ein neu gemessener Blickort innerhalb eines Ellipsoiden um das Zentrum der
// *  der stattfindenden Fixation liegt, wird die Fixation um den neuen Blickort erweitert. Die Dimension des
// *  Akzeptanzbereiches bzw. Ellipsoiden wird vom Benutzer durch das Setzen des Funktionsargumentes fAccuracyAngle
// *  vorgegeben. Dieser Winkel gibt die Genauigkeit der Messung in Abh�ngigkeit des verwendeten Eyetrackingsystems an und
// *  variiert horzonzal bzw. vertikal weniger als in die Tiefe. Deshalb kann auch keine Kugel als dreidimensionaler
// *  Fixationsk�per angenommen werden. Der Ellipsoid wird durch den aktuellen Fixationsort, dem Genauigkeitswinkel der Messung
// *  und der Aussrichtung zu den Augen des Probanden definiert. F�r die Ausrichtung wird ein Zyklpenauge als Mittelpunkt zwischen
// *  den dreidimensionalen Corneazentren des linken und rechten Auges angenommen und der Ellipsoid daran dreidimensional ausgerichtet.
// *
// *  Um St�rungen in der Blickortmessungen zu ber�cksichtigen, wird ein einzelner Blickort, der die Abweichung in einer
// *  laufenden Fixation �berschreitet, ebenfalls in die Fixation aufgenommen, sofern das nachfolgende Sample wieder
// *  innerhalb des Akzeptanzbereiches dieser Fixation liegt.
// *
// *  Sollte kein G�ltiger Blickort vorliegen (z.B. w�hrend eines Blinks), wird die die Fixation verl�ngert, falls:
// *
// *	a) das n�chste g�ltige Sample wieder innerhalb des Akzeptanzbereiches liegt,
// *  b) es weniger als iMinimumFixSamples aufeinanderfolgender fehlender Blickorte gibt.
// *
// *  Andernfalls wird die Fixation an Stelle der letzten g�ltigen bzw. guten Messung beendet.
// *
// *
// *  MASSEINHEITEN
// *  =============
// *
// *  Die Blickpositionen/Blickrichtungen k�nnen in beliebigen Einheiten angegeben werden (z.B. mm, px, rd), jedoch muss
// *  die Angabe der Filterwerte in denselben Einheiten erfolgen.
// *
// *
// *  INITIALISIERUNG DER FUNKTION
// *  ============================
// *
// *  Bevor Blickortsequenzen analysiert werden, sollte die InitFixation Funktion aufgerufen werden, um alle vorherigen,
// *  gegenw�rtigen und neuen Fixationsdaten zu l�schen und die Ringpuffer mit den vorherigen Blickortdaten zu
// *  initialisieren.
// *
// *
// *  PROGRAMM-HINWEIWSE
// *  ==================
// *
// *  Aus Dokumentationsgr�nden wird innerhalb einer Fixationssequenz die jeweiligen Fixationen als "previous",
// *  "present", und "new" bezeichnet.
// *
// *  Die �present� Fixation ist die derzeitig ablaufende bzw. falls eine neue Fixation startet die bereits abgeschlossene.
// *  Die �previous� Fixation ist die unmittelbar der gegenw�rtigen vorausgegangene und die �new� Fixation die
// *  unmittelbar folgende Fixation. Sobald die �present� Fixation f�r beendet erkl�rt ist, wird die �present� Fixation zur
// *  �previous� und die �new� zur �present�. Eine neue Fixation gibt es bis jetzt noch nicht.
// *
// *--------------------------------------------------------------------------------------------------------------------------*/



var
  iPastRingIndex: Integer;
  i: Integer;
begin

  // * Stelle sicher, dass die minimale Anzahl an Samples zur Erkennung einer Fixation 3 betr�gt.
  if (iMinimumFixSamples < 3) then
    iMinimumFixSamples := 3;

  // * Stelle sicher, dass die Ring-Gr��e gro� genug f�r die Pufferung der Daten ist.
  Assert(iMinimumFixSamples < RING_SIZE);

  // * Erh�he den Aufrufz�hler, den Ringindex und den Ringindex-Versatz.
  Inc(iDfCallCount);
  iPastRingIndex := iCurrentRingIndex;
  Inc(iCurrentRingIndex);
  if (iCurrentRingIndex >= RING_SIZE) then
    iCurrentRingIndex := 0;
  iRingIndexDelay := iCurrentRingIndex - iMinimumFixSamples;
  if (iRingIndexDelay < 0) then
    Inc(iRingIndexDelay, RING_SIZE);

  Assert((iCurrentRingIndex >= 0) and (iCurrentRingIndex < RING_SIZE));
  Assert((iRingIndexDelay >= 0) and (iRingIndexDelay < RING_SIZE));

  // * Aktualisiere den Ringpuffer mit dem letzten Blickort.
  stRingBuf[iCurrentRingIndex].iDfCallCount := iDfCallCount;
  stRingBuf[iCurrentRingIndex].fXGaze := fXGaze;
  stRingBuf[iCurrentRingIndex].fYGaze := fYGaze;
  stRingBuf[iCurrentRingIndex].fZGaze := fZGaze;

  stRingBuf[iCurrentRingIndex].bGazeFound := bGazepointFound;

  // * Zun�chst nehme an, dass sich das Auge bewegt.
  // * Hinweis: Diese Werte werden w�hrend der weiteren Verarbeitung dieses und der folgenden Blickorte aktualisiert.

  stRingBuf[iCurrentRingIndex].iEyeMotionState := MOVING;

  stRingBuf[iCurrentRingIndex].fXFix := -0;
  stRingBuf[iCurrentRingIndex].fYFix := -0;
  stRingBuf[iCurrentRingIndex].fZFix := -0;

  stRingBuf[iCurrentRingIndex].fXEllipsoidR:= -0;
  stRingBuf[iCurrentRingIndex].fYEllipsoidR:= -0;
  stRingBuf[iCurrentRingIndex].fZEllipsoidR:= -0;

  stRingBuf[iCurrentRingIndex].fEllipsoidYaw:= -0;
  stRingBuf[iCurrentRingIndex].fEllipsoidPitch:= -0;

//  stRingBuf[iCurrentRingIndex].fGazeDeviation := -0.1;
  stRingBuf[iCurrentRingIndex].iFixDuration := 0;
                                                                                    asdf
  // * Der folgende Code erh�ht die Sakkadendauer w�hrend nicht fixierender Perioden.
  // * Falls das Auge bereits im letzten Sample in Bewegung war, �
  if (stRingBuf[iPastRingIndex].iEyeMotionState = MOVING) then
  begin
    // * � erh�he den Sakkadenz�hler des letzten Samples.
    stRingBuf[iCurrentRingIndex].iSacDuration := stRingBuf[iPastRingIndex].iSacDuration + 1;
  end
  // * Andererseits, falls das Auge w�hrend des letzten Samples Fixiert hat, �
  else
  begin
    // * � setze den Sakkadenz�hler auf 1, initialisiere das Sample in der Annahme, dass es sich um das erste Sample einer
    // * beginnenden Sakkade handelt.
    stRingBuf[iCurrentRingIndex].iSacDuration := 1;
  end;

  // *- - - - - - - - - - - - - Prozess f�r getrackte Augen - - - - - - - - - - - - - -*/

  // * A) Falls das Sample einen g�ltigen Blickort enth�lt, �
  if (bGazepointFound = TRUE) then
  begin
    // * A1 B) Falls eine Fixationshypothese f�r die gegenw�rtige Fixation existiert
    if (stFix[PRES_FIX].iNEyeFoundSamples > 0) then
    begin
      // *       B1) Berechne den Abstand zwischen Blickort und gegenw�rtiger Fixation und pr�fe, ob sich der Blickort innerhalb des Akzeptanzbereiches liegt.
      bGazeInPresFix := IsGazeInFix(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

      // *       C) Falls der Blickort innerhalb des Akzeptanzbereiches liegt, �
      if bGazeInPresFix=TRUE then
      begin
        // *          C1) - Aktualisiere die Fixaionshypothese der gegenw�rtigen Fixation
        // *              - pr�fe, ob die gegenw�rtige Fixation real ist, und falls ja,
        // *              - kennzeichne die vorangegangenen Eintr�ge im Ringpuffer als Fixationspunkte.
        UpdateFixationHypothesis(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
      end

      // *       Falls der neue Blickort au�erhalb des Aktzeptanzbereiches liegt �
      else // if bGazeInPresFix=FALSE
      begin
        // *          C2) Erh�he den Z�hler f�r aufeinanderfolgende Samples au�erhalb des Akzeptanzbereiches.
        Inc(iNOutsidePresEllipsoid);

        // *          D) Falls die Anzahl aufeinanderfolgender Samples au�erhalb liegender Punkte das Maximum NICHT �bersteigt, �
        if (iNOutsidePresEllipsoid <= iMaxOutSamples) then
        begin
          // *             D1) Nimm den Blickort in die NEUE Fixationshypothese (NEW_FIXATION) auf.
          // *             	    E)     Falls diese neue Fixationshypothese bereits gestartet wurde, �
          if (stFix[NEW_FIX].iNEyeFoundSamples > 0) then
          begin
            // *                   E1) � berechne den Blickortabstand zur neuen Fixation.
            bGazeInNewFix := IsGazeInFix(NEW_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

            // *                   F) Falls der neue Blickort in die neue Fixation f�llt, �
            if bGazeInNewFix=TRUE then
            begin
              // *                      F1) 	- Aktualisiere die Fixationhypothese der NEW_FIXATION und
              // *                      	    - �berpr�fe, ob es dort gen�gend Samples gibt, um das Auge als �fixierend� zu deklarieren, und
              // *                            - falls dem so ist, kennzeichne die vorangegangenen Eintr�ge im Ringpuffer als
              // *                              Fixationspunkte.
              UpdateFixationHypothesis(NEW_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
            end

            // *   Falls der neue Blickort auch au�erhalb der neuen Fixation liegt, �
            else // if (fNewDr > fGazeDeviationThreshold)
            begin
              // *                       F2) Setze die neue Fixation auf diesen neuen Blickort zur�ck.
              StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
            end;
          end

          // *  Falls die neue Fixationshypothese noch gar nicht gestartet ist,
          else // if (stFix[NEW_FIX].iNEyeFoundSamples == 0)
          begin
            // *                E2) Starte die neue Fixationshypothese an diesem Blickort.
            StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
          end;
        end

        // *   Falls zu viele aufeinanderfolgende Samples au�erhalb des Akzeptanzbereiches liegen, �
        else // if (iNOutsidePresCircle > iMaxOutSamples)
        begin
          // *             D2) muss die Fixationshypothese der PRES_FIXATION als abgeschlossen oder abgelehnt deklariert werden.
          // *             G) Falls diese best�tigt werden kann, �
          if (stFix[PRES_FIX].bFixationVerified = TRUE) then
          begin
            // *                G1) - Erkl�re die PRES_FIX am letzten guten Sample als abgeschlossen,
            // *                    - Mache die PRES_FIX zur PREV_FIX und die
            // *                    - die NEW_FIX zur PRES_FIX
            DeclarePresentFixationComplete(iMinimumFixSamples);
          end

          // *   Falls es nicht gen�gend gute Samples zur Bestimmung einer Fixation gibt,
          else // if (stFix[PRES_FIX].bFixationVerified == FALSE)
          begin
            // *                G2) Verwerfe die Fixationshypothese der PRES_FIX, in dem diese durch die neue Fixation NEW_FIX
            // *                    ausgetauscht wird, die zu diesem Zeitpunkt existiert, oder auch nicht existiert.
            MoveNewFixToPresFix();
          end;

          // *             H) Falls es eine Fixationshypothese f�r PRES_FIX gibt, �
          if (stFix[PRES_FIX].iNEyeFoundSamples > 0) then
          begin
            // *                H1) Berechne den Abstand des Blickortes zur jetzt neuen PRES_FIXATION (kurz vorher noch NEW_FIX).
            bGazeInPresFix := IsGazeInFix(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad);

            // *                I) Falls der Blickort innerhalb des Akzeptanzbereiches der jetzt neuen  PRES_FIX liegt, �
            if bGazeInPresFix = TRUE then
            begin
              // *                   I1) - Aktualisiere PRES_FIX,
              // *                        - �berpr�fe, ob es dort gen�gend Samples gibt, um das Auge als �fixierend� zu deklarieren, und
              // *                        - falls dem so ist, kennzeichne die vorangegangenen Eintr�ge im Ringpuffer als
              // *                          Fixationspunkte.
              UpdateFixationHypothesis(PRES_FIX, fXLeftEye, fYLeftEye, fZLeftEye, fXRightEye, fYRightEye, fZRightEye, fXGaze, fYGaze, fZGaze, fAccuracyAngleRad, iMinimumFixSamples);
            end

            // * Andernfalls, falls der Blickort au�erhalb des Akzeptanzbereiches liegt, �
            else // if (fPresDr > fGazeDeviationThreshold)
            begin
              // *                   I2) Starte eine neue Fixationshypothese f�r NEW_FIX an diesem Blickort.
              StartFixationHypothesisAtGazepoint(NEW_FIX, fXGaze, fYGaze, fZGaze);
            end;
          end

          // * Andernfalls, falls es keine Fixationshypothese f�r PRES_FIX gibt, �
          else // if (stFix[PRES_FIX].iNEyeFoundSamples == 0)
          begin
            // *                H2) Starte eine neue Fixationshypothese f�r  PRES_FIX an diesem Blickort.
            StartFixationHypothesisAtGazepoint(PRES_FIX, fXGaze, fYGaze, fZGaze);
          end;
        end;
      end;
    end

    // * Andernfalls, falls es keine Fixationshypothese f�r PRES_FIX gibt, �
    else // if (stFix[PRES_FIX].iNEyeFoundSamples == 0)
    begin
      // *       B2) Starte eine neue Fixationshypothese f�r  PRES_FIX an diesem Blickort und l�sche die f�r NEW_FIX
      StartFixationHypothesisAtGazepoint(PRES_FIX, fXGaze, fYGaze, fZGaze);
    end;
  end

  // *- - - - - - - - - - - - - Prozess f�r NICHT getrackte Augen  - - - - - - - - - - - - -*/

  // * Andernfalls, wenn das Sample keinen g�ltigen Blickort aufweist, �
  else // if (bGazepointFound == FALSE)
  begin
    // *    A2 J) Falls der Ausfall noch innerhalb der zul�ssingen Grenzen liegt, z.B. innerhalb des Zeitfenster f�r maximal
    // *          ung�ltige Samples liegt, �
    if (iDfCallCount - stFix[PRES_FIX].iEndCount <= iMaxMissedSamples) then
    begin
      // *       J1) � brauch hier NICHTS unternommen werden.
    end

    // *    Andernfalls, wenn die Ausfalll�cke zum letzten guten Sample zu gro� ist, �
    else // if (iDFCallCount - stFix[PRES_FIX].iEndCount > iMaxMissedSamples)
    begin
      // *       J2) � muss die Fixationshypothese f�r PRES_FIX abgelehnt oder f�r abgeschlossen erkl�rt werden:
      // *       K) Falls die Fixationshypothese best�tigt werden kann, �
      if (stFix[PRES_FIX].bFixationVerified = TRUE) then
      begin
        // *          K1) - Erkl�re die PRES_FIX am letzten guten Sample als abgeschlossen,
        // *              - Mache die PRES_FIX zur PREV_FIX und die
        // *              - die NEW_FIX zur PRES_FIX
        DeclarePresentFixationComplete(iMinimumFixSamples);
      end

      // * Andernfalls, wenn die Fixationshypothese f�r PRES_FIX nicht best�tig werden kann, �
      else // if (stFix[PRES_FIX].bFixationVerified == FALSE)
      begin
        // *          K2) Verwerfe die Fixationshypothese der PRES_FIX, in dem diese durch die neue Fixation NEW_FIX
       // *               ausgetauscht wird, die zu diesem Zeitpunkt existiert, oder auch nicht existiert.
        MoveNewFixToPresFix();
      end;
    end;
  end;

  // *---------------------------- Pass Data Back ------------------------------*/

  Assert((iRingIndexDelay >= 0) and (iRingIndexDelay < RING_SIZE));

  // * Gib die verz�gerten Blickortdaten, mit den entsprechenden Sakkaden-/Fixationsinformationen an die aufrufende
  // * Funktion zur�ck (werden als Output-Parameter zur�ckgegeben).

  pbGazepointFoundDelayed := stRingBuf[iRingIndexDelay].bGazeFound;

  pfXGazeDelayed := stRingBuf[iRingIndexDelay].fXGaze;
  pfYGazeDelayed := stRingBuf[iRingIndexDelay].fYGaze;
  pfZGazeDelayed := stRingBuf[iRingIndexDelay].fZGaze;

  pfXFixDelayed := stRingBuf[iRingIndexDelay].fXFix;
  pfYFixDelayed := stRingBuf[iRingIndexDelay].fYFix;
  pfZFixDelayed := stRingBuf[iRingIndexDelay].fZFix;

  pfXEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fXEllipsoidR;
  pfYEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fYEllipsoidR;
  pfZEllipsoidRDelayed := stRingBuf[iRingIndexDelay].fZEllipsoidR;

  pfEllipsoidYawDelayed := stRingBuf[iRingIndexDelay].fEllipsoidYaw;
  pfEllipsoidPitchDelayed := stringBuf[iRingIndexDelay].fEllipsoidPitch;

  piSacDurationDelayed := stRingBuf[iRingIndexDelay].iSacDuration;
  piFixDurationDelayed := stRingBuf[iRingIndexDelay].iFixDuration;

  // * R�ckgabewert der Funktion als Bewegungs/Fixationsstatus (Eye Motion State) des VERZ�GERTEN Blickortes.
  Result := stRingBuf[iRingIndexDelay].iEyeMotionState;

  ///////////////////////////////////////////////////////////////////////////////
  ///
  /// Global Output Parameters
  ///

  for i := 0 to RING_SIZE do
    gb_stRingBuf[i]:=stRingBuf[i];

  for i := 0 to 2 do
    gb_stFix[i]:=stFix[i];


end;




procedure TFixFuncClass3dCalcByEllipsoidWP.TestPresentFixationHypothesis(iMinimumFixSamples: Integer);

// * Diese Funktion testet, ob es gen�gend Samples in der gegenw�rtigen Fixationshypothese gibt, um das Auge als
// * 'fixierend� zu deklarieren. Falls eine Fixation l�uft, aktualisiert die Funktion die entsprechenden momentanen und
// * fr�heren Ringpuffereintr�ge, die zur Fixation geh�ren.

var
  iEarlierPointOffset: Integer; 	// * Index-Offset zum jetzigen Ringpufferindex
  iDumRingIndex: Integer; 		    // * Dummy Ringindex

 // * Falls es gen�gend g�ltige Samples in der Fixationshypothese f�r PRES_FIX gibt, um eine reale Fixation zu bestimmen,
 // * ...
begin
  if (stFix[PRES_FIX].iNEyeFoundSamples >= iMinimumFixSamples) then
  begin
    // *    Deklariere das Auge als �fixierend�. Gehe r�ckw�rts durch die letzten iMinimumFixSamples Eintr�ge des
    // *    Ringpuffers inklusive des aktuellen Punktes, �
    for iEarlierPointOffset := 0 to iMinimumFixSamples - 1 do
    begin
      // *    Berechne den Ringindex des fr�heren Zeitpunktes
      iDumRingIndex := iCurrentRingIndex - iEarlierPointOffset;
      if (iDumRingIndex < 0) then
        Inc(iDumRingIndex, RING_SIZE);

      Assert((iDumRingIndex >= 0) and (iDumRingIndex < RING_SIZE));

      // *       Markiere den Punkt als �fixierend� bzw. innerhalb der Fixation.
      stRingBuf[iDumRingIndex].iEyeMotionState := FIXATING;
      stRingBuf[iDumRingIndex].fXFix := stFix[PRES_FIX].fX;
      stRingBuf[iDumRingIndex].fYFix := stFix[PRES_FIX].fY;
      stRingBuf[iDumRingIndex].fZFix := stFix[PRES_FIX].fZ;

      // *       Setze den Ringpuffereintrag f�r die Sakkadendauer.
      // *       Hinweis: Diese ist f�r alle Punkte identisch.
      stRingBuf[iDumRingIndex].iSacDuration := stFix[PRES_FIX].iStartCount - stFix[PREV_FIX].iEndCount - 1;

      // *       Setze den Ringpuffereintrag f�r die Fixationsdauer, z.B. die Zeit zwischen Start der gegenw�rtigen Fixation und
      // *       die durch den Ringindex angegebene Zeit.
      // *       Hinweis: Die Fixationsdauer verringert sich bei fr�her erfassten Punkten innerhalb der Fixation.
      stRingBuf[iDumRingIndex].iFixDuration := stFix[PRES_FIX].iEndCount - iEarlierPointOffset - stFix[PRES_FIX].iStartCount + 1;

    end;

  end;
end;

end.


