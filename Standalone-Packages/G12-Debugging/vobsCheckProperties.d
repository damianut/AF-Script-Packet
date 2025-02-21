/*
 *
 */
func string Vob_GetPortalNameAndPosition (var int vobPtr) {
	var int x;
	var int y;
	var int z;

	var int pos[3];

	var string portalRoom;

	var string s;

	//Get portal room
	s = Vob_GetPortalName (vobPtr);

	s = ConcatStrings (", portalroom: '", s);
	s = ConcatStrings (s, "'");

	//Get position
	if (zCVob_GetPositionWorldToPos (vobPtr, _@ (pos))) {

		x = roundF (pos[0]);
		y = roundF (pos[1]) + 250; //add just enough for player to be able to teleport to location
		z = roundF (pos[2]);

		s = ConcatStrings (s, ", pos: ");
		s = ConcatStrings (s, IntToString (x));
		s = ConcatStrings (s, " ");

		s = ConcatStrings (s, IntToString (y));
		s = ConcatStrings (s, " ");

		s = ConcatStrings (s, IntToString (z));
	};

	return s;
};

/*
 *	oCMob_CheckProperties
 *	 - checks properties of oCMob objects
 *	 - you can call this function from Init_Global () function to validate all locks
 */
func void oCMob_CheckProperties () {
	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();

	var string msg;

	zSpy_Info ("oCMob_CheckProperties -->");
	msg = oCWorld_GetWorldFilename ();
	msg = ConcatStrings (" - world: ", msg);
	zSpy_Info (msg);

	//Case sensitive!
	if (!SearchVobsByClass ("oCMOB", vobListPtr)) {
		MEM_ArrayFree (vobListPtr);
		zSpy_Info (" - no oCMOB objects found.");
		zSpy_Info ("oCMob_CheckProperties <--");
		return;
	};

	//List of already listed issues err msgs (to prevent duplicates)
	var int errListPtr; errListPtr = MEM_ArrayCreate ();

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	var int i;
	var int issueCounter;

	var oCMob mob;
	var oCMobLockable mobLockable;

	issueCounter = 0;

	repeat (i, vobList.numInArray);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		if (Hlp_Is_oCMob (vobPtr)) {
			mob = _^ (vobPtr);
			msg = "";

			var int ownerStrHasToBeTrimmed; ownerStrHasToBeTrimmed = FALSE;
			var int ownerGuildStrHasToBeTrimmed; ownerGuildStrHasToBeTrimmed = FALSE;

			var int ownerStrInvalid; ownerStrInvalid = FALSE;
			var int ownerGuildStrInvalid; ownerGuildStrInvalid = FALSE;

			//--> check for extra spaces in ownerStr or ownerGuildStr
			var string ownerStr; ownerStr = mob.ownerStr;
			var string ownerGuildStr; ownerGuildStr = mob.ownerGuildStr;

			var int lenOwnerStr; lenOwnerStr = STR_Len (ownerStr);
			var int lenOwnerGuildStr; lenOwnerGuildStr = STR_Len (ownerGuildStr);

			ownerStr = STR_Trim (ownerStr, " ");
			ownerGuildStr = STR_Trim (ownerGuildStr, " ");

			if (lenOwnerStr != STR_Len (ownerStr)) {
				ownerStrHasToBeTrimmed = TRUE;
			};

			if (lenOwnerGuildStr != STR_Len (ownerGuildStr)) {
				ownerGuildStrHasToBeTrimmed = TRUE;
			};
			//<--

			//--> check invalid symbols (trimmed at this point)
			var int symbID;

			if (STR_Len (ownerStr)) {
				symbID = MEM_FindParserSymbol (ownerStr);
				if (symbID == -1) {
					ownerStrInvalid = TRUE;
				};
			};

			if (STR_Len (ownerGuildStr)) {
				symbID = MEM_FindParserSymbol (ownerGuildStr);
				if (symbID == -1) {
					ownerGuildStrInvalid = TRUE;
				};
			};

			//Report to zSpy:
			if (ownerStrHasToBeTrimmed || ownerGuildStrHasToBeTrimmed || ownerStrInvalid || ownerGuildStrInvalid) {
				issueCounter += 1;

				msg = ConcatStrings (" - oCMOB: '", mob.name);
				msg = ConcatStrings (msg, "'");

				msg = ConcatStrings (msg, Vob_GetPortalNameAndPosition (vobPtr));

				if (ownerStrHasToBeTrimmed) {
					msg = ConcatStrings (msg, ", ownerStr contains spaces: '");
					msg = ConcatStrings (msg, mob.ownerStr);
					msg = ConcatStrings (msg, "'");
				};

				if (ownerGuildStrHasToBeTrimmed) {
					msg = ConcatStrings (msg, ", ownerGuildStr contains spaces: '");
					msg = ConcatStrings (msg, mob.ownerGuildStr);
					msg = ConcatStrings (msg, "'");
				};

				if (ownerStrInvalid) {
					msg = ConcatStrings (msg, ", ownerStr is invalid : '");
					msg = ConcatStrings (msg, ownerStr);
					msg = ConcatStrings (msg, "'");
				};

				if (ownerGuildStrInvalid) {
					msg = ConcatStrings (msg, ", ownerGuildStr is invalid: '");
					msg = ConcatStrings (msg, ownerGuildStr);
					msg = ConcatStrings (msg, "'");
				};

				if (!MEM_StringArrayContains (errListPtr, msg)) {
					//Insert err msg to array
					MEM_StringArrayInsert (errListPtr, msg);

					zSpy_Info (msg);
				};
			};

			//We can fix this one from scripts:
			if (ownerStrHasToBeTrimmed || ownerGuildStrHasToBeTrimmed) {
				//Update owner strings (this will update oCMOB.owner & oCMOB.ownerGuild properties)
				oCMob_SetOwnerStr (vobPtr, ownerStr, ownerGuildStr);
			};
		};
	end;

	//It's nicer if we have 2 loops and output is split by object category
	repeat (i, vobList.numInArray);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		if (Hlp_Is_oCMobLockable (vobPtr)) {
			mobLockable = _^ (vobPtr);

			msg = "";

			var int pickLockStrValid; pickLockStrValid = TRUE;
			var int keyIsValid; keyIsValid = TRUE;

			//Check if pickLockStr is valid (only combination of L and R)
			if (STR_Len (mobLockable.pickLockStr)) {
				var string pickLockStr; pickLockStr = mobLockable.pickLockStr;
				pickLockStr = STR_ReplaceAll (pickLockStr, "L", "");
				pickLockStr = STR_ReplaceAll (pickLockStr, "R", "");

				pickLockStr = STR_Trim (pickLockStr, " ");

				pickLockStrValid = (STR_Len (pickLockStr) == 0);
			};

			//Check if key is valid
			if (STR_Len (mobLockable.keyInstance)) {
				keyIsValid = MEM_FindParserSymbol (mobLockable.keyInstance);
			};

			if ((keyIsValid == -1) || (pickLockStrValid == FALSE)) {
				issueCounter += 1;

				//Get name
				msg = ConcatStrings (" - oCMobLockable: '", mobLockable._oCMob_name);
				msg = ConcatStrings (msg, "'");

				//Get key
				msg = ConcatStrings (msg, ", key: '");
				msg = ConcatStrings (msg, mobLockable.keyInstance);
				msg = ConcatStrings (msg, "'");

				//Get picklock combination
				msg = ConcatStrings (msg, ", pickLockStr: '");
				msg = ConcatStrings (msg, mobLockable.pickLockStr);
				msg = ConcatStrings (msg, "'");

				msg = ConcatStrings (msg, Vob_GetPortalNameAndPosition (vobPtr));

				if (keyIsValid == -1) {
					//Key does not exits
					msg = ConcatStrings (msg, " has an invalid key - item does not exist!");
				};

				if (pickLockStrValid == FALSE) {
					//Key does not exits
					msg = ConcatStrings (msg, " has an invalid pickLockStr!");
				};

				if (!MEM_StringArrayContains (errListPtr, msg)) {
					//Insert err msg to array
					MEM_StringArrayInsert (errListPtr, msg);

					zSpy_Info (msg);
				};
			};
		};
	end;

	MEM_StringArrayFree (errListPtr);
	MEM_ArrayFree (vobListPtr);

	if (issueCounter == 0) {
		zSpy_Info (" - no issues detected.");
	};

	zSpy_Info ("oCMob_CheckProperties <--");
};

/*
 *	zCTrigger_CheckProperties
 *	 - checks properties of zCTrigger objects
 *	 - you can call this function from Init_Global () function to validate all locks
 */
func void zCTrigger_CheckProperties () {
	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();

	var string msg;

	zSpy_Info ("zCTrigger_CheckProperties -->");
	msg = oCWorld_GetWorldFilename ();
	msg = ConcatStrings (" - world: ", msg);
	zSpy_Info (msg);

	//Case sensitive!
	if (!SearchVobsByClass ("zCTrigger", vobListPtr)) {
		MEM_ArrayFree (vobListPtr);
		zSpy_Info (" - no zCTrigger objects found.");
		zSpy_Info ("zCTrigger_CheckProperties <--");
		return;
	};

	//List of already listed issues err msgs (to prevent duplicates)
	var int errListPtr; errListPtr = MEM_ArrayCreate ();

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	var int i;

	var int issueCounter; issueCounter = 0;

	var zCTrigger trigger;

	repeat (i, vobList.numInArray);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		if (Hlp_Is_zCTrigger (vobPtr)) {
			trigger = _^ (vobPtr);
			msg = "";

			var int countTriggerTarget; countTriggerTarget = 0;
			var int triggerTargetHasToBeTrimmed; triggerTargetHasToBeTrimmed = FALSE;
			var int triggerTargetInvalid; triggerTargetInvalid = FALSE;

			//--> check for extra spaces in triggetTarget
			var string triggerTarget; triggerTarget = trigger.triggerTarget;

			var int lenTriggerTarget; lenTriggerTarget = STR_Len (triggerTarget);

			triggerTarget = STR_Trim (triggerTarget, " ");

			if (lenTriggerTarget != STR_Len (triggerTarget)) {
				triggerTargetHasToBeTrimmed = TRUE;
			};
			//<--

			//--> check invalid symbols (trimmed at this point)
			var int symbID;

			if (STR_Len (triggerTarget)) {
				countTriggerTarget = Vob_GetNoOfVobsByName (triggerTarget);

				if (!countTriggerTarget) {
					msg = ConcatStrings (" - zCTrigger: '", trigger._zCObject_objectName);
					msg = ConcatStrings (msg, "'");

					msg = ConcatStrings (msg, ", triggerTarget not found: '");
					msg = ConcatStrings (msg, triggerTarget);
					msg = ConcatStrings (msg, "'");

					if (!MEM_StringArrayContains (errListPtr, msg)) {
						//Insert err msg to array
						MEM_StringArrayInsert (errListPtr, msg);

						zSpy_Info (msg);
					};
				};

				if (countTriggerTarget > 1) {
					msg = ConcatStrings (" - zCTrigger: '", trigger._zCObject_objectName);
					msg = ConcatStrings (msg, "'");

					msg = ConcatStrings (msg, ", multiple triggerTargets found.");
					msg = ConcatStrings (msg, triggerTarget);
					msg = ConcatStrings (msg, "'");

					if (!MEM_StringArrayContains (errListPtr, msg)) {
						//Insert err msg to array
						MEM_StringArrayInsert (errListPtr, msg);

						zSpy_Info (msg);
					};
				};

				symbID = MEM_FindParserSymbol (triggerTarget);
				if (symbID == -1) {
					triggerTargetInvalid = TRUE;
				};
			};

			//Report to zSpy:
			if (triggerTargetInvalid || triggerTargetHasToBeTrimmed) {
				issueCounter += 1;

				msg = ConcatStrings (" - zCTrigger: '", trigger._zCObject_objectName);
				msg = ConcatStrings (msg, "'");

				msg = ConcatStrings (msg, Vob_GetPortalNameAndPosition (vobPtr));

				if (triggerTargetHasToBeTrimmed) {
					msg = ConcatStrings (msg, ", triggerTarget contains spaces: '");
					msg = ConcatStrings (msg, trigger.triggerTarget);
					msg = ConcatStrings (msg, "'");
				};

				if (triggerTargetInvalid) {
					msg = ConcatStrings (msg, ", triggerTarget is invalid: '");
					msg = ConcatStrings (msg, triggerTarget);
					msg = ConcatStrings (msg, "'");
				};

				if (!MEM_StringArrayContains (errListPtr, msg)) {
					//Insert err msg to array
					MEM_StringArrayInsert (errListPtr, msg);

					zSpy_Info (msg);
				};
			};
		};
	end;

	MEM_StringArrayFree (errListPtr);
	MEM_ArrayFree (vobListPtr);

	if (issueCounter == 0) {
		zSpy_Info (" - no issues detected.");
	};

	zSpy_Info ("zCTrigger_CheckProperties <--");
};

func void Game_CheckObjectRoutines () {
	var string msg;

	zSpy_Info ("Game_CheckObjectRoutines -->");

	msg = oCWorld_GetWorldFilename ();
	msg = ConcatStrings (" - world: ", msg);
	zSpy_Info (msg);

	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();
	if (!SearchVobsByClass ("oCMobInter", vobListPtr)) {
		zSpy_Info (" - no oCMobInter objects found.");
	};

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	//List of already listed issues err msgs (to prevent duplicates)
	var int errListPtr; errListPtr = MEM_ArrayCreate ();

	//List of all checked visuals
	var int visListPtr; visListPtr = MEM_ArrayCreate ();

	var int i;
	var int j;

	var int ptr; ptr = MEM_Game.objRoutineList_next;

	while (ptr);
		var zCListSort l; l = _^ (ptr);

		if (l.data) {
			var TObjectRoutine oRtn;
			oRtn = _^ (l.data);

			//type 0 - all objects with **sceme** will be triggered
			//type 1 - single object will be triggerer
			if (oRtn.type == 0) {
				var int flagMobFound; flagMobFound = FALSE;

				repeat (i, vobList.numInArray);
					vobPtr = MEM_ArrayRead (vobListPtr, i);

					if (vobPtr) {
						var oCMobInter mobInter; mobInter = _^ (vobPtr);

						if (Hlp_StrCmp (mobInter.sceme, oRtn.objName)) {
							flagMobFound = TRUE;
							break;
						};
					};
				end;

				if (!flagMobFound) {
					msg = ConcatStrings (" - no oCMobInter found with sceme name: ", oRtn.objName);
					msg = ConcatStrings (msg, " --> Wld_SetMobRoutine is using sceme name to trigger objects.");

					if (!MEM_StringArrayContains (errListPtr, msg)) {
						//Insert err msg to array
						MEM_StringArrayInsert (errListPtr, msg);

						zSpy_Info (msg);
					};
				};
			} else
			if (oRtn.type == 1) {

				var int arr; arr = MEM_SearchAllVobsByName (oRtn.objName);
				var zCArray zarr; zarr = _^ (arr);

				if (zarr.numInArray == 0) {
					msg = ConcatStrings (" - object not found: ", oRtn.objName);

					if (!MEM_StringArrayContains (errListPtr, msg)) {
						//Insert err msg to array
						MEM_StringArrayInsert (errListPtr, msg);

						zSpy_Info (msg);
					};
				} else {
					if (zarr.numInArray > 1) {
						msg = ConcatStrings (" - multiple objects found (", IntToString (zarr.numInArray));
						msg = ConcatStrings (msg, "): ");
						msg = ConcatStrings (msg, oRtn.objName);
						msg = ConcatStrings (msg, " --> Wld_SetObjectRoutine updates 1 object, you might have to rename duplicates.");

						if (!MEM_StringArrayContains (errListPtr, msg)) {
							//Insert err msg to array
							MEM_StringArrayInsert (errListPtr, msg);

							zSpy_Info (msg);
						};
					};

					//Check all oCMobInter objects - all objects with same visual should have object routines (maybe?!)

					//Get first vobPtr
					vobPtr = MEM_ArrayRead (arr, 0);
					var string visualName; visualName = Vob_GetVisualName (vobPtr);

					//If this is new visual ...
					if (!MEM_StringArrayContains (visListPtr, visualName))
					{
						//Insert visual to array
						MEM_StringArrayInsert (visListPtr, visualName);

						repeat (i, vobList.numInArray);
							vobPtr = MEM_ArrayRead (vobListPtr, i);

							if (vobPtr) {
								if (Hlp_StrCmp (visualName, Vob_GetVisualName (vobPtr))) {

									var int flagObjRtnFound; flagObjRtnFound = FALSE;

									//Loop again through all object routines (uh how performance heavy will this be?)
									var int ptr2; ptr2 = MEM_Game.objRoutineList_next;
									while (ptr2);
										var zCListSort l2; l2 = _^ (ptr2);

										if (l2.data) {
											var TObjectRoutine oRtn2;
											oRtn2 = _^ (l2.data);

											var zCVob vob; vob = _^ (vobPtr);

											if (Hlp_StrCmp (vob._zCObject_objectName, oRtn2.objName)) {
												flagObjRtnFound = TRUE;
												break;
											};
										};

										ptr2 = l2.next;
									end;

									if (!flagObjRtnFound) {
										msg = ConcatStrings (" - (warning - potential issue) object does not have object routine: ", vob._zCObject_objectName);
										msg = ConcatStrings (msg, " --> objects with same visual have object routines setup.");

										if (!MEM_StringArrayContains (errListPtr, msg)) {
											//Insert err msg to array
											MEM_StringArrayInsert (errListPtr, msg);

											zSpy_Info (msg);
										};
									};
								};
							};
						end;
					};
				};

				MEM_ArrayFree (arr);
			};
		};

		ptr = l.next;
	end;

	MEM_StringArrayFree (visListPtr);
	MEM_StringArrayFree (errListPtr);
	MEM_ArrayFree (vobListPtr);

	zSpy_Info ("Game_CheckObjectRoutines <--");
};

func void Vobs_CheckProperties () {
	Game_CheckObjectRoutines ();
	oCMob_CheckProperties ();
	zCTrigger_CheckProperties ();
};
