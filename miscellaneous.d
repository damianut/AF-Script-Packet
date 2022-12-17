/*
 *	Miscellaneous functions
 *	 - these functions are very useful, but I felt they should not be in same files as other more 'generic' functions.
 */

/*
 *	Function traverses through all oCMobInter objects and updates onStateFunc, conditionFunc and useWithItem for all objects, which do have specified visual name.
 *	Usage:
 *
 *	oCMobInter_SetupAllMobsByVisual ("ORE_GROUND.ASC", "MINING", "", "ITMWPICKAXE");
 */
func void oCMobInter_SetupAllMobsByVisual (var string searchVisual, var string onStateFunc, var string conditionFunc, var string useWithItem) {
	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();

	if (!SearchVobsByClass ("oCMobInter", vobListPtr)) {
		MEM_ArrayFree (vobListPtr);
		MEM_Info ("oCMobInter_SetupAllMobsByVisual: No oCMobInter objects found.");
		return;
	};

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	var int i; i = 0;

	var int count; count = vobList.numInArray;

	var string mobVisualName;

	while (i < count);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		//Get visual name
		mobVisualName = Vob_GetVisualName (vobPtr);

		if (Hlp_StrCmp (mobVisualName, searchVisual)) {
			oCMobInter_SetOnStateFuncName (vobPtr, onStateFunc);
			oCMobInter_SetConditionFunc (vobPtr, conditionFunc);
			oCMobInter_SetUseWithItem (vobPtr, useWithItem);
		};

		i += 1;
	end;

	MEM_ArrayFree (vobListPtr);
};

/*
 *	oCMobContainer_SearchByPortalRoom
 *	 - function returns first pointer to chest with searchVisual located in portal room searchPortalRoom
 */
func int oCMobContainer_SearchByPortalRoom (var string searchVisual, var string searchPortalRoom) {
	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();

	if (!SearchVobsByClass ("oCMobContainer", vobListPtr)) {
		MEM_ArrayFree (vobListPtr);
		MEM_Info ("oCMobContainer_SearchByPortalRoom: No oCMobContainer objects found.");
		return 0;
	};

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	var int i; i = 0;

	var int count; count = vobList.numInArray;

	var string mobVisualName;
	var string mobPortalRoom;

	while (i < count);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		//Get visual name
		mobVisualName = Vob_GetVisualName (vobPtr);

		if (Hlp_StrCmp (mobVisualName, searchVisual)) {
			mobPortalRoom = Vob_GetPortalName (vobPtr);

			if (Hlp_StrCmp (mobPortalRoom, searchPortalRoom)) {
				MEM_ArrayFree (vobListPtr);
				return vobPtr;
			};
		};

		i += 1;
	end;

	MEM_ArrayFree (vobListPtr);
	return 0;
};

func void test_G2A_InsertItemsToChestsInOldCampCastle () {
	var int chestPtr;

	chestPtr = oCMobContainer_SearchByPortalRoom ("CHESTBIG_OCCHESTLARGELOCKED.MDS", "KI1");

	if (chestPtr) {
		FillMobContainer (chestPtr, "ItMi_Nugget:10");
	};

	chestPtr = oCMobContainer_SearchByPortalRoom ("CHESTBIG_OCCHESTLARGE.MDS", "KI3");

	if (chestPtr) {
		FillMobContainer (chestPtr, "ItMi_Nugget:12");
	};
};

/*
 *
 *	Vob list functions
 *
 */

/*
 *	NPC_VobListDetectScemeName
 *	 - function returns pointer to *nearest* available mob with specified scemeName with specified state within specified verticalLimit
 *	 - vob list has to be generated prior calling this function (oCNpc_ClearVobList (self); oCNpc_CreateVobList (self, rangeF);)
 */
func int NPC_VobListDetectScemeName (var int slfInstance, var string scemeName, var int state, var int availabilityCheck, var int searchFlags, var int distLimit, var int verticalLimit) {
	var oCNPC slf; slf = Hlp_GetNPC (slfInstance);
	if (!Hlp_IsValidNPC (slf)) { return 0; };

	var int dist;
	var int maxDist; maxDist = 999999;

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var int canSee;
	var int available;

	var int vobPtr;
	var int i; i = 0;

	//Get Npc position
	var int fromPos[3];
	var int retVal; retVal = zCVob_GetPositionWorldToPos (_@ (slf), _@ (fromPos));

	//Target position
	var int toPos[3];
	var int routePtr;

	while (i < slf.vobList_numInArray);
		vobPtr = MEM_ReadIntArray (slf.vobList_array, i);

		if (availabilityCheck) {
			available = oCMobInter_IsAvailable (vobPtr, slf);
		} else {
			available = Hlp_Is_oCMobInter (vobPtr);
		};

		if (available) {
			if (searchFlags & SEARCHVOBLIST_CANSEE) {
				canSee = oCNPC_CanSee (slfInstance, vobPtr, 1);
			} else {
				canSee = TRUE;
			};

			//Check for portal room owner
			if (searchFlags & SEARCHVOBLIST_CHECKPORTALROOMOWNER) {
				var string portalName; portalName = Vob_GetPortalName (vobPtr);

				//If portal room is owned by Npc
				if (Wld_PortalGetOwnerInstanceID (portalName) > -1) {
					//If this portal is not owned by me - ignore - pretend we don't see it :)
					if (!Wld_PortalIsOwnedByNPC (portalName, slf)) {
						canSee = FALSE;
					};
				};
			};

			if (canSee) {
				if ((abs (NPC_GetHeightToVobPtr (slf, vobPtr)) < verticalLimit) || (verticalLimit == -1)) {
					if (STR_StartsWith (oCMobInter_GetScemeName (vobPtr), scemeName)) {
						var oCMobInter mob; mob = _^ (vobPtr);
						if ((mob.state == state) || (state == -1)) {
							//Find route from Npc to vob - get total distance if Npc travels by waynet
							if (searchFlags & SEARCHVOBLIST_USEWAYNET) {
								retVal = zCVob_GetPositionWorldToPos (vobPtr, _@ (toPos));
								routePtr = zCWayNet_FindRoute_Positions (_@ (fromPos), _@ (toPos), 0);
								dist = zCRoute_GetLength (routePtr); //float
								dist = RoundF (dist);
							} else {
								dist = NPC_GetDistToVobPtr (slfInstance, vobPtr); //int
							};

							if ((dist <= distLimit) || (distLimit == -1)) {
								if (!firstPtr) { firstPtr = vobPtr; };

								if (dist < maxDist) {
									nearestPtr = vobPtr;
									maxDist = dist;
								};
							};
						};
					};
				};
			};
		};
		i += 1;
	end;

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

/*
 *	NPC_VobListDetectVisual
 *	 - function returns pointer to *nearest* vob with specified searchVisualName within specified verticalLimit
 *	 - vob list has to be generated prior calling this function (oCNpc_ClearVobList (self); oCNpc_CreateVobList (self, rangeF);)
 */
func int NPC_VobListDetectVisual (var int slfInstance, var string searchVisualName, var int searchFlags, var int distLimit, var int verticalLimit) {
	var oCNPC slf; slf = Hlp_GetNPC (slfInstance);
	if (!Hlp_IsValidNPC (slf)) { return 0; };

	var int dist;
	var int maxDist; maxDist = 999999;

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var string visualName;

	var int canSee;

	var int vobPtr;
	var int i; i = 0;

	//Get Npc position
	var int fromPos[3];
	var int retVal; retVal = zCVob_GetPositionWorldToPos (_@ (slf), _@ (fromPos));

	//Target position
	var int toPos[3];
	var int routePtr;

	while (i < slf.vobList_numInArray);
		vobPtr = MEM_ReadIntArray (slf.vobList_array, i);

		if (searchFlags & SEARCHVOBLIST_CANSEE) {
			canSee = oCNPC_CanSee (slfInstance, vobPtr, 1);
		} else {
			canSee = TRUE;
		};

		//Check for portal room owner
		if (searchFlags & SEARCHVOBLIST_CHECKPORTALROOMOWNER) {
			var string portalName; portalName = Vob_GetPortalName (vobPtr);

			//If portal room is owned by Npc
			if (Wld_PortalGetOwnerInstanceID (portalName) > -1) {
				//If this portal is not owned by me - ignore - pretend we don't see it :)
				if (!Wld_PortalIsOwnedByNPC (portalName, slf)) {
					canSee = FALSE;
				};
			};
		};

		if (canSee) {
			if ((abs (NPC_GetHeightToVobPtr (slf, vobPtr)) < verticalLimit) || (verticalLimit == -1)) {
				visualName = Vob_GetVisualName (vobPtr);

				if (Hlp_StrCmp (visualName, searchVisualName)) {
					//Find route from Npc to vob - get total distance if Npc travels by waynet
					if (searchFlags & SEARCHVOBLIST_USEWAYNET) {
						retVal = zCVob_GetPositionWorldToPos (vobPtr, _@ (toPos));
						routePtr = zCWayNet_FindRoute_Positions (_@ (fromPos), _@ (toPos), 0);
						dist = zCRoute_GetLength (routePtr); //float
						dist = RoundF (dist);
					} else {
						dist = NPC_GetDistToVobPtr (slfInstance, vobPtr); //int
					};

					if ((dist <= distLimit) || (distLimit == -1)) {
						if (!firstPtr) { firstPtr = vobPtr; };

						if (dist < maxDist) {
							nearestPtr = vobPtr;
							maxDist = dist;
						};
					};
				};
			};
		};

		i += 1;
	end;

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

/*
 *	NPC_VobListDetectItem
 *	 - function returns pointer to *nearest* item with specified mainflag and flags within specified verticalLimit
 *	 - vob list has to be generated prior calling this function (oCNpc_ClearVobList (self); oCNpc_CreateVobList (self, rangeF);)
 */
func int NPC_VobListDetectItem (var int slfInstance, var int mainflag, var int excludeMainFlag, var int flags, var int excludeFlags, var int searchFlags, var int distLimit, var int verticalLimit) {
	var oCNPC slf; slf = Hlp_GetNPC (slfInstance);
	if (!Hlp_IsValidNPC (slf)) { return 0; };

	var int dist;
	var int maxDist; maxDist = 999999;

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var oCItem itm;

	var int canSee;

	var int vobPtr;
	var int i; i = 0;

	//Get Npc position
	var int fromPos[3];
	var int retVal; retVal = zCVob_GetPositionWorldToPos (_@ (slf), _@ (fromPos));

	//Target position
	var int toPos[3];
	var int routePtr;

	while (i < slf.vobList_numInArray);
		vobPtr = MEM_ReadIntArray (slf.vobList_array, i);
		if (Hlp_Is_oCItem (vobPtr)) {

			if (searchFlags & SEARCHVOBLIST_CANSEE) {
				canSee = oCNPC_CanSee (slfInstance, vobPtr, 1);
			} else {
				canSee = TRUE;
			};

			//Check for portal room owner
			if (searchFlags & SEARCHVOBLIST_CHECKPORTALROOMOWNER) {
				var string portalName; portalName = Vob_GetPortalName (vobPtr);

				//If portal room is owned by Npc
				if (Wld_PortalGetOwnerInstanceID (portalName) > -1) {
					//If this portal is not owned by me - ignore - pretend we don't see it :)
					if (!Wld_PortalIsOwnedByNPC (portalName, slf)) {
						canSee = FALSE;
					};
				};
			};

			if (canSee) {
				if ((abs (NPC_GetHeightToVobPtr (slf, vobPtr)) < verticalLimit) || (verticalLimit == -1)) {
					itm = _^ (vobPtr);
					if (Hlp_IsValidItem (itm)) {
						if (((!mainflag) || (itm.mainflag == mainflag))
						&& ((!excludeMainFlag) || (itm.mainflag != excludeMainFlag)))
						{
							if (((!flags) || (itm.flags & flags))
							&& ((!excludeFlags) || (!(itm.flags & excludeFlags))))
							{
								//Find route from Npc to vob - get total distance if Npc travels by waynet
								if (searchFlags & SEARCHVOBLIST_USEWAYNET) {
									retVal = zCVob_GetPositionWorldToPos (vobPtr, _@ (toPos));
									routePtr = zCWayNet_FindRoute_Positions (_@ (fromPos), _@ (toPos), 0);
									dist = zCRoute_GetLength (routePtr); //float
									dist = RoundF (dist);
								} else {
									dist = NPC_GetDistToVobPtr (slfInstance, vobPtr); //int
								};

								if ((dist <= distLimit) || (distLimit == -1)) {
									if (!firstPtr) { firstPtr = vobPtr; };

									if (dist < maxDist) {
										nearestPtr = vobPtr;
										maxDist = dist;
									};
								};
							};
						};
					};
				};
			};
		};
		i += 1;
	end;

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

func int NPC_VobListDetectNpc (var int slfInstance, var string stateName, var int searchFlags, var int distLimit, var int verticalLimit) {
	var oCNPC slf; slf = Hlp_GetNPC (slfInstance);
	if (!Hlp_IsValidNPC (slf)) { return 0; };

	var int dist;
	var int maxDist; maxDist = 999999;

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var oCNPC npc;

	var int canSee;

	var int vobPtr;
	var int i; i = 0;

	//Get Npc position
	var int fromPos[3];
	var int retVal; retVal = zCVob_GetPositionWorldToPos (_@ (slf), _@ (fromPos));

	//Target position
	var int toPos[3];
	var int routePtr;

	while (i < slf.vobList_numInArray);
		vobPtr = MEM_ReadIntArray (slf.vobList_array, i);
		if (Hlp_Is_oCNpc (vobPtr)) {

			if (searchFlags & SEARCHVOBLIST_CANSEE) {
				canSee = oCNPC_CanSee (slfInstance, vobPtr, 1);
			} else {
				canSee = TRUE;
			};

			//Check for portal room owner
			if (searchFlags & SEARCHVOBLIST_CHECKPORTALROOMOWNER) {
				var string portalName; portalName = Vob_GetPortalName (vobPtr);

				//If portal room is owned by Npc
				if (Wld_PortalGetOwnerInstanceID (portalName) > -1) {
					//If this portal is not owned by me - ignore - pretend we don't see it :)
					if (!Wld_PortalIsOwnedByNPC (portalName, slf)) {
						canSee = FALSE;
					};
				};
			};

			if (canSee) {
				if ((abs (NPC_GetHeightToVobPtr (slf, vobPtr)) < verticalLimit) || (verticalLimit == -1)) {
					npc = _^ (vobPtr);
					if (NPC_IsInStateName (npc, stateName)) {
						//Find route from Npc to vob - get total distance if Npc travels by waynet
						if (searchFlags & SEARCHVOBLIST_USEWAYNET) {
							retVal = zCVob_GetPositionWorldToPos (vobPtr, _@ (toPos));
							routePtr = zCWayNet_FindRoute_Positions (_@ (fromPos), _@ (toPos), 0);
							dist = zCRoute_GetLength (routePtr); //float
							dist = RoundF (dist);
						} else {
							dist = NPC_GetDistToVobPtr (slfInstance, vobPtr); //int
						};

						if ((dist <= distLimit) || (distLimit == -1)) {
							if (!firstPtr) { firstPtr = vobPtr; };

							if (dist < maxDist) {
								nearestPtr = vobPtr;
								maxDist = dist;
							};
						};
					};
				};
			};
		};
		i += 1;
	end;

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

func int NPC_VobListDetectByName (var int slfInstance, var string objectName, var int searchFlags, var int distLimit, var int verticalLimit) {
	var oCNPC slf; slf = Hlp_GetNPC (slfInstance);
	if (!Hlp_IsValidNPC (slf)) { return 0; };

	objectName = STR_Upper (objectName);

	var int dist;
	var int maxDist; maxDist = 999999;

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var oCNPC npc;

	var int canSee;

	var int vobPtr;
	var int i; i = 0;

	//Get Npc position
	var int fromPos[3];
	var int retVal; retVal = zCVob_GetPositionWorldToPos (_@ (slf), _@ (fromPos));

	//Target position
	var int toPos[3];
	var int routePtr;

	while (i < slf.vobList_numInArray);
		vobPtr = MEM_ReadIntArray (slf.vobList_array, i);
		if (vobPtr) {

			if (searchFlags & SEARCHVOBLIST_CANSEE) {
				canSee = oCNPC_CanSee (slfInstance, vobPtr, 1);
			} else {
				canSee = TRUE;
			};

			//Check for portal room owner
			if (searchFlags & SEARCHVOBLIST_CHECKPORTALROOMOWNER) {
				var string portalName; portalName = Vob_GetPortalName (vobPtr);

				//If portal room is owned by Npc
				if (Wld_PortalGetOwnerInstanceID (portalName) > -1) {
					//If this portal is not owned by me - ignore - pretend we don't see it :)
					if (!Wld_PortalIsOwnedByNPC (portalName, slf)) {
						canSee = FALSE;
					};
				};
			};

			if (canSee) {
				if ((abs (NPC_GetHeightToVobPtr (slf, vobPtr)) < verticalLimit) || (verticalLimit == -1)) {
					var zCVob vob; vob = _^ (vobPtr);

					if (Hlp_StrCmp (STR_Upper (vob._zCObject_objectName), objectName)) {
						//Find route from Npc to vob - get total distance if Npc travels by waynet
						if (searchFlags & SEARCHVOBLIST_USEWAYNET) {
							retVal = zCVob_GetPositionWorldToPos (vobPtr, _@ (toPos));
							routePtr = zCWayNet_FindRoute_Positions (_@ (fromPos), _@ (toPos), 0);
							dist = zCRoute_GetLength (routePtr); //float
							dist = RoundF (dist);
						} else {
							dist = NPC_GetDistToVobPtr (slfInstance, vobPtr); //int
						};

						if ((dist <= distLimit) || (distLimit == -1)) {
							if (!firstPtr) { firstPtr = vobPtr; };

							if (dist < maxDist) {
								nearestPtr = vobPtr;
								maxDist = dist;
							};
						};
					};
				};
			};
		};
		i += 1;
	end;

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

/*
 *	zCVob_GetNearest_AtPos
 *	 - function returns first pointer to object closest to fromPosPtr
 */
func int zCVob_GetNearest_AtPos (var string className, var int fromPosPtr) {
	var int vobListPtr; vobListPtr = MEM_ArrayCreate ();

	if (!SearchVobsByClass (className, vobListPtr)) {
		MEM_ArrayFree (vobListPtr);
		var string msg;
		msg = ConcatStrings ("zCVob_GetNearest_AtPos: No ", className);
		msg = ConcatStrings (msg, " objects found.");
		MEM_Info (msg);
		return 0;
	};

	var int dist;
	var int maxDist; maxDist = mkf (999999);

	var int firstPtr; firstPtr = 0;
	var int nearestPtr; nearestPtr = 0;

	var int vobPtr;
	var zCArray vobList; vobList = _^ (vobListPtr);

	var int i; i = 0;

	var int count; count = vobList.numInArray;

	var int dir[3];
	var int posPtr;

	while (i < count);
		//Read vobPtr from vobList array
		vobPtr = MEM_ArrayRead (vobListPtr, i);

		if (vobPtr) {
			if (!firstPtr) { firstPtr = vobPtr; };

			posPtr = zCVob_GetPositionWorld (vobPtr);
			SubVectors (_@ (dir), fromPosPtr, posPtr);
			MEM_Free (posPtr);

			dist = zVEC3_LengthApprox (_@ (dir));

			if (lf (dist, maxDist)) {
				nearestPtr = vobPtr;
				maxDist = dist;
			};
		};

		i += 1;
	end;

	MEM_ArrayFree (vobListPtr);

	if (nearestPtr) { return nearestPtr; };

	return firstPtr;
};

/*
 *	Fight mode functions
 */

/*
 *	Switch to fist mode
 */
func void FM_SetToFistMode (var int slfInstance) {
	var C_NPC slf; slf = Hlp_GetNpc (slfInstance);
	if (Npc_IsInFightMode (slf, FMODE_FIST)) { return; };

	var int itemPtr; itemPtr = oCNpc_GetWeapon (slf);
	if (itemPtr) {
		AI_RemoveWeapon (slf);
	};

	AI_DrawWeapon_Ext (slf, FMODE_FIST, 1); //Melee - fists
};

/*
 *	Switch to fight mode (specific melee weapon)
 */
func void FM_SetToMelee (var int slfInstance, var int itemInstanceID) {
	var C_NPC slf; slf = Hlp_GetNpc (slfInstance);
	if (!Npc_HasItems (slf, itemInstanceID)) { return; };

	var int itemPtr; itemPtr = oCNpc_GetWeapon (slf);
	if (itemPtr) {
		var oCItem itm; itm = _^ (itemPtr);
		//Is this weapon that we want to draw?
		if (Hlp_GetInstanceID (itm) == itemInstanceID) {
			return;
		};
	};

	if ((itemPtr) || (Npc_IsInFightMode (slf, FMODE_FIST))) {
		AI_RemoveWeapon (slf);
	};

	if (Npc_GetInvItem (slf, itemInstanceID)) {
		if ((item.Flags & ITEM_ACTIVE_LEGO) == FALSE) {
			AI_UnequipMeleeWeapon (slf);
			AI_EquipItemPtr (slf, _@ (item));
		};
	};

	AI_DrawWeapon_Ext (slf, FMODE_FIST, 0); //Melee
};

/*
 *	Switch to fight mode (specific ranged weapon)
 */
func void FM_SetToRanged (var int slfInstance, var int itemInstanceID) {
	var C_NPC slf; slf = Hlp_GetNpc (slfInstance);
	if (!Npc_HasItems (slf, itemInstanceID)) { return; };

	var int itemPtr; itemPtr = oCNpc_GetWeapon (slf);
	if (itemPtr) {
		var oCItem itm; itm = _^ (itemPtr);
		//Is this weapon that we want to draw?
		if (Hlp_GetInstanceID (itm) == itemInstanceID) {
			return;
		};
	};

	//Remove weapon
	if ((itemPtr) || (Npc_IsInFightMode (slf, FMODE_FIST))) {
		AI_RemoveWeapon (slf);
	};

	//Equip weapon if not equipped
	if (Npc_GetInvItem (slf, itemInstanceID)) {
		if ((item.Flags & ITEM_ACTIVE_LEGO) == FALSE) {
			AI_UnequipRangedWeapon (slf);
			AI_EquipItemPtr (slf, _@ (item));
		};
	};

	AI_DrawWeapon_Ext (slf, FMODE_FAR, 0); //Ranged
};

//--

func int GetSymbolIntValue (var int symbolIndex) {
	var int symbPtr; symbPtr = MEM_GetSymbolByIndex (symbolIndex);

	if (symbPtr) {
		var zCPar_symbol symb; symb = _^ (symbPtr);

		if ((symb.bitfield & zCPar_Symbol_bitfield_type) == zPAR_TYPE_INT)
		|| ((symb.bitfield & zCPar_Symbol_bitfield_type) == zPAR_TYPE_FLOAT) {
			return symb.content;
		};
	};

	return 0;
};

func string GetSymbolStringValue (var int symbolIndex) {
	var int symbPtr; symbPtr = MEM_GetSymbolByIndex (symbolIndex);

	if (symbPtr) {
		var zCPar_symbol symb; symb = _^ (symbPtr);

		if ((symb.bitfield & zCPar_Symbol_bitfield_type) == zPAR_TYPE_STRING) {
			var string s; s = MEM_ReadString(symb.content);
			return s;
		};
	};

	return "";
};

func string API_GetSymbolStringValue (var string symbolName, var string defaultValue) {
	var int symbID; symbID = MEM_GetSymbolIndex (symbolName);

	if (symbID == -1) {
		return defaultValue;
	};

	var string s; s = GetSymbolStringValue (symbID);
	return s;
};

func int API_GetSymbolIntValue (var string symbolName, var int defaultValue) {
	var int symbID; symbID = MEM_GetSymbolIndex (symbolName);

	if (symbID == -1) {
		return defaultValue;
	};

	return + GetSymbolIntValue (symbID);
};

/*
 *	 - wrapper function that converts value from hex to RGBA
 */
func int API_GetSymbolHEX2RGBAValue (var string symbolName, var string defaultValue) {
	var int symbID; symbID = MEM_GetSymbolIndex (symbolName);

	if (symbID == -1) {
		return + HEX2RGBA (defaultValue);
	};

	var string s; s = GetSymbolStringValue (symbID);
	return + HEX2RGBA (s);
};

/*
 *	Basically copy of MEM_CallByString - without any error messaging
 */
func void API_CallByString (var string fnc) {
    var int symbID;
    const string cacheFunc = ""; const int cacheSymbID = 0;

    if (Hlp_StrCmp (cacheFunc, fnc)) {
        symbID = cacheSymbID;
    } else {
        symbID = MEM_FindParserSymbol (fnc);

        if (symbID == -1) {
           return;
        };

        cacheFunc = fnc; cacheSymbID = symbID;
    };

    MEM_CallByID (symbID);
};
