
	Fixation3D.dll - Dispersionsbasierte Erkennung dreidimensionaler Fixationen mit ellipsoiden Toleranzbereich
	===========================================================================================================


    Datum:           	20.05.2016
    Autor:      		Sascha Weber (sascha.weber@tu-dresden.de)
						

	Implementierung:	Die dreidimensionale Fixationserkennung mit ellipsoiden Toleranzbereich wurde in Kooperation mit
                        Dixon Cleveland (LC-Technologies, Inc.) in die bislang zweidimensionale Logik der
                        Eyegaze Analysis System Fixationserkennung implementiert und auf die dritte Dimension erweitert.

                        Original 2D-Fixationserkennung			File Name:       FIXFUNC.C
                                                                Program Name:    Eye Fixation Analysis Functions
                                                                Company:         LC Technologies, Inc.
                                                                                 10363 Democracy Lane
                                                                                 Fairfax, VA 22030
                                                                                 (703) 385-8800
                                                                
																Date Created:    10/20/89
                                                                                 04/12/95 modified: turned into collection of functions

	   
    Zusammenfassung:   	Diese Bibliothek kapselt die Funktionen aus Gaze3DFix\src\Fixation3D.dll\units\FixFuncClass3dCalcByEllipsoid.pas
						   					 
						Der 3D-Fixationserkennung werden dreidimensionale Blickorte übergeben und anhand einstellbarer Parameter
                        geprüft, ob sich die 3D-Blickorte innerhalb eines ellipsoiden Toleranzberereich befinden. Liegt die
                        minimale Anzahl an Samples innerhalb der ellispoiden Fixationshülle, wird die Fixationshypothese bestätigt.
                        Mit jedem neuen Sample wird die Fixationshypothese erneut geprüft und bei Bestätigung das neue Sample der
                        bestehenden Fixation hinzugefügt. Die Rückgabewerte beinhalten u.a. die Parameter der dreidimensionalen Fixation.
                        Die detaillierte Beschreibung der Parameter und Algorithmen erfolgt im Source-Code der Datei
						FixFuncClass3dCalcByEllipsoid.pas.
         
		 
	Funktionen: 	    1. 	Initialisierung der ellipsoiden Fixationserkennung: Übergeben wird die minimale Anzahl an Samples, die einer Fixation
																				zugeordnet werden müssen. Die Initialisierung wird einmal vor 
																				der Übergabe aller 3D-Blickorte aufgerufen.
																				
		
							function Init3DFixation (iMinimumSamples: Integer): Integer; stdcall;    					// *	Rückgabe: 0 fehlgeschlagen, 1 erfolgreich   	      


							
						
						
						2.	Übergabe der 3D-Blickorte und Detektion dreidimensionaler Fixtaionen:						
						
							function Calculate3DFixation(  	bValidSample: Integer;										// *  Indikator, ob der bildverarbeitende Algorithmus gültige Blickdaten
																														// *  für beide Augen gefunden hat: 0=FALSE, 1=TRUE (Bei einem Blink = 0)
																														
															fXLeftEye, fYLeftEye, fZLeftEye,							// *  Koordinaten linkes Auge
															fXRightEye, fYRightEye, fZRightEye,							// *  Koordinaten rechtes Auge
															
															fXGaze, fYGaze, fZGaze: Single;								// *  aktueller 3D-Blickort
															
															fAccuracyAngleRad: Single;          						// *  Schwellwert für die Berechnung der ellipsoiden Fixationshülle

															iMinimumFixSamples: Integer; 		    					// *  minimale Anzahl an Gaze Samples, um eine Fixation zu erkennen.
																														// *  Beachte: Falls dieser Wert mit weniger als 3 beträgt,
																														// * 	       wird er automatisch auf 3 gesetzt.
														
														
																														// *  OUTPUT PARAMETER: Verzögerte Blickortdaten um iMinimumSixSamples

													out		pbGazepointFoundDelayed: Integer;							// *  Indikator, ob das Sample war - iMinimumFixSamples vorher
													
													out 	pfXGazeDelayed, pfYGazeDelayed, pfZGazeDelayed: Single;		// *  Blickortkoordinaten - iMinimumFixSamples vorher
													
													out 	pfXFixDelayed, pfYFixDelayed, pfZFixDelayed: Single;		// *  Fixationszentrum - iMinimumFixSamples vorher
													
													out 	pfXEllipsoidRDelayed, pfYEllipsoidRDelayed,					// *  Ausdehnung des Ellipsoiden - iMinimumFixSamples vorher
															pfZEllipsoidRDelayed: Single;	
															
													out  	pfEllipsoidYawDelayed, pfEllipsoidPitchDelayed: Single;		// *  Ausrichtung des Ellipsoiden: Eulersche Winkel im Kartesischen 
																														// *  Koordinatensystem zur Koordinatentransformation und Drehung der 
																														// *  Fixation im Raum	
																														// *  yaw angle (Rotation der Fixation um die Y-Achse)
																														// *  pitch angle (Rotation der Fixation um die X-Achse)
																														
													
													out  	piSacDurationDelayed, 										// *  Dauer der Sakkade, die der gegenwärtigen Fixation voranging (Samples)
															piFixDurationDelayed: Integer):Integer; stdcall;			// *  Dauer der gegenwärtigen Fixation (Samples)


																														// *  Rückgabewerte - Eye Motion State:
																														// *
																														// *    MOVING			    0   Das Auge war in Bewegung, iMinimumFixSamples vorher.
																														// *    FIXATING			1   Das Auge fixierte, iMinimumFixSamples vorher.
																														// *    FIXATION_COMPLETED 	2	Eine abgeschlossene Fixation wurde erkannt, iMinimumFixSamples vorher.
																														// *
																														// *	In Bezug auf das Sample, welches FIXATION_COMPLETED zurück gibt, startete die Fixation
																														// *	(iMinimumFixSamples + *piSaccadeDurationDelayed) vorher und endete iMinimumFixSamples vorher.
																														// *
																														

	Beschreibung
	===============

    Die Fixationserkennung konvertiert eine Serie gleichmäßig abgetasteter Blickpunkte in eine Serie von Sakkaden und Fixationen variabler Dauer.

    Die Fixationserkennung kann in Echtzeit oder auch nachträglich erfolgen. Um die Fixationserkennung während der
    Blickdatenaufzeichnung (Echtzeit) durchführen zu können, muss diese Funktion für jedes Sample aufgerufen werden.

    Falls das Auge in Bewegung ist, z.B. während einer Sakkade, gibt diese Funktion 0 (MOVING) zurück.
    Falls das Auge stillsteht, z.B. während einer Fixation gibt die Funktion 1 (FIXATING)  zurück.
    Falls eine abgeschlossene Fixation erkannt wird, gibt die Funktion 2 (FIXATION_COMPLETED) mit folgenden
    Parametern zurück:

    	a) Die Sakkadendauer zwischen der letzten und gegenwärtigen Fixation (samples)
    	b) Die Dauer der gegenwärtigen, jetzt abgeschlossenen Fixation
    	c) Die durchschnittlichen x- und y- Koordinaten der Fixation

    Beachte: Obwohl diese Funktion  in Echtzeit arbeitet, gibt es eine Verzögerung von iMinimumFixSamples im Filter,
             welcher die Bewegung/Fixation des Auges erkennt.

  
    PRINZIP DES 3D-ALGORITHMUS
    ==========================

	Diese Funktion erkennt Fixationen mittels Suche nach Sequenzen gemessener Blickorte, die relativ konstant sind bzw.
	am selben Ort verharren. Falls ein neu gemessener Blickort innerhalb eines Ellipsoiden um das Zentrum der
	der stattfindenden Fixation liegt, wird die Fixation um den neuen Blickort erweitert. Die Dimension des
	Akzeptanzbereiches bzw. Ellipsoiden wird vom Benutzer durch das Setzen des Funktionsargumentes fAccuracyAngle
	vorgegeben. Dieser Winkel gibt den Toleranzbereich der ellipsoiden Fixationserkennung an und
	variiert horzonzal bzw. vertikal weniger als in die Tiefe. Deshalb kann auch keine Kugel als dreidimensionaler
	Fixationsköper angenommen werden. Der Ellipsoid wird durch den aktuellen Fixationsort, dem Toleranzwinkel
	und der Aussrichtung zu den Augen des Probanden definiert. Für die Ausrichtung wird ein Zyklpenauge als Mittelpunkt zwischen
	den dreidimensionalen Positionen des linken und rechten Auges angenommen und der Ellipsoid daran dreidimensional ausgerichtet.

	Um Störungen in der Blickortmessungen zu berücksichtigen, wird ein einzelner Blickort, der die Abweichung in einer
	laufenden Fixation überschreitet, ebenfalls in die Fixation aufgenommen, sofern das nachfolgende Sample wieder
	innerhalb des Akzeptanzbereiches dieser Fixation liegt.

	Sollte kein Gültiger Blickort vorliegen (z.B. während eines Blinks), wird die die Fixation verlängert, falls:

		a) das nächste gültige Sample wieder innerhalb des Akzeptanzbereiches liegt,
		b) es weniger als iMinimumFixSamples aufeinanderfolgender fehlender Blickorte gibt.

	Andernfalls wird die Fixation an Stelle der letzten gültigen bzw. guten Messung beendet.


	MASSEINHEITEN
	=============
	
	Die Blickpositionen/Blickrichtungen können in beliebigen Einheiten angegeben werden (z.B. mm, px, rd), jedoch muss
    die Angabe der Filterwerte in denselben Einheiten erfolgen.


	INITIALISIERUNG DER FUNKTION
	============================
	
	Bevor Blickortsequenzen analysiert werden, sollte die InitFixation Funktion aufgerufen werden, um alle vorherigen,
	gegenwärtigen und neuen Fixationsdaten zu löschen und die Ringpuffer mit den vorherigen Blickortdaten zu
	initialisieren.


	
															
							
						
						