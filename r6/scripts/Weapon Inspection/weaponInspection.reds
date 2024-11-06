module WeaponInspection
// Refers to Always First Equip mod

enum FirstEquipHotkeyState {
    IDLE = 0,
    PREPARING = 1,
    TAPPED = 2,
    HOLD_STARTED = 3,
    HOLD_ENDED = 4,
}

private static func WeaponInspectionAction() -> CName = n"WeaponInspection" 

public class WeaponInspectionInputListener {
    private let m_player: wref<PlayerPuppet>;
    // For Ranged weapons, if you want to use Other animation instead of FirstEquip:
    // replace "ifOtherAnim" with true, and "animationName" with its name
    private let ifOtherAnim: Bool = false;
    private let animationName: CName = n"IdleBreak";

    public func SetPlayer(player: ref<PlayerPuppet>) -> Void {
        this.m_player = player;
    }

    // Catch FirstTimeEquip hotkey press
    protected cb func OnAction(action: ListenerAction, consumer: ListenerActionConsumer) -> Bool {
        let drawItemRequest: ref<DrawItemRequest>;
        let equipmentSystem: ref<ScriptableSystem> = GameInstance.GetScriptableSystemsContainer(this.m_player.GetGame()).Get(n"EquipmentSystem");
        let equipmentSystemData: ref<EquipmentSystemPlayerData> = EquipmentSystem.GetData(this.m_player);
        let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.m_player.GetGame());
        let uiSystem = GameInstance.GetBlackboardSystem(this.m_player.GetGame()).Get(GetAllBlackboardDefs().UI_System);

        if !IsDefined(this.m_player) {
            return false;
        }

        if Equals(ListenerAction.GetName(action), WeaponInspectionAction()) {
            let pressed: Bool = Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_PRESSED);
            let released: Bool = Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_RELEASED);
            let hold: Bool = Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_HOLD_COMPLETE);
            let itemID = equipmentSystemData.GetSlotActiveItem(EquipmentManipulationRequestSlot.Right);

            if itemID.IsValid() {
                // If item is equipped
                // Log(ToString(pressed) + " " + ToString(released) + " " + ToString(hold) + " " + ToString(this.m_player.firstEqHotkeyState));
                uiSystem.SetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyPressed, pressed, false);
                uiSystem.SetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyReleased, released, false);
                uiSystem.SetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyHold, hold, false);
                
                if !transactionSystem.HasTag(this.m_player, n"MeleeWeapon", itemID) {  
                    // If not melee weapon
                    if this.ifOtherAnim {
                        AnimationControllerComponent.PushEvent(this.m_player, this.animationName);
                        return true;
                    }

                    if Equals(this.m_player.firstEqHotkeyState, FirstEquipHotkeyState.PREPARING) {
                        if !pressed && released && !hold {
                            equipmentSystemData.RemoveItemFromSlotActiveItem(itemID);
                        } else {
                            return true;
                        }
                    } else {
                        return false;
                    }
                } else if pressed && !released && !hold {
                    // If melee and hotkey pressed
                    equipmentSystemData.RemoveItemFromSlotActiveItem(itemID);
                }
            } else {
                // If no item equipped
                itemID = equipmentSystemData.GetLastUsedItemID(ELastUsed.Weapon);
            }
            // Draw item to trigger FirstEquip animation
            drawItemRequest = new DrawItemRequest();
            drawItemRequest.itemID = itemID;
            drawItemRequest.owner = this.m_player;
            equipmentSystem.QueueRequest(drawItemRequest);
        }
    }
}

@addField(PlayerPuppet) let WeaponInspectionInputListener: ref<WeaponInspectionInputListener>;
@addField(PlayerPuppet) let skipFirstEquip: Bool;

@addField(PlayerPuppet) let firstEqHotkeyState: FirstEquipHotkeyState;
@addField(ReadyEvents) let savedIdleTimestamp: Float;
@addField(ReadyEvents) let safeAnimFeature: ref<AnimFeature_SafeAction>;
@addField(ReadyEvents) let weaponObjectId: TweakDBID;
@addField(ReadyEvents) let isHoldActive: Bool;
@addField(ReadyEvents) let readyStateRequested: Bool;
@addField(ReadyEvents) let safeStateRequested: Bool;

@addField(UI_SystemDef) let FirstEquipRequested: BlackboardID_Bool;
@addField(UI_SystemDef) let FirstEqHotkeyPressed: BlackboardID_Bool;
@addField(UI_SystemDef) let FirstEqHotkeyReleased: BlackboardID_Bool;
@addField(UI_SystemDef) let FirstEqHotkeyHold: BlackboardID_Bool;
@addField(UI_SystemDef) let FirstEqLastUsedSlot: BlackboardID_Int;
@addField(UI_SystemDef) let SafeStateRequested: BlackboardID_Bool;


@wrapMethod(PlayerPuppet)
protected cb func OnGameAttached() -> Bool {
    wrappedMethod();
    this.WeaponInspectionInputListener = new WeaponInspectionInputListener();
    this.WeaponInspectionInputListener.SetPlayer(this);
    this.RegisterInputListener(this.WeaponInspectionInputListener);
}

@wrapMethod(PlayerPuppet)
protected cb func OnDetach() -> Bool {
    wrappedMethod();
    this.UnregisterInputListener(this.WeaponInspectionInputListener);
    this.WeaponInspectionInputListener = null;
}

@addMethod(PlayerPuppet)
public func SetSkipFirstEquipEQ(skip: Bool) -> Void {
    this.skipFirstEquip = skip;
}

@addMethod(PlayerPuppet)
public func ShouldSkipFirstEquipEQ() -> Bool {
    return this.skipFirstEquip;
}

// SET SKIP ANIMATION FLAGS
@wrapMethod(EquipCycleDecisions)
protected final const func ToFirstEquip(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Bool {
    return false;
}

// IdleBreak and SafeAction
@wrapMethod(ReadyEvents)
protected final func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
    // Initialize new fields
    playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.IDLE;
    this.savedIdleTimestamp = this.m_timeStamp;
    this.safeAnimFeature = new AnimFeature_SafeAction();
    this.weaponObjectId = TweakDBInterface.GetWeaponItemRecord(ItemID.GetTDBID(DefaultTransition.GetActiveWeapon(scriptInterface).GetItemID())).GetID();
    this.isHoldActive = false;
    this.readyStateRequested = false;
    this.safeStateRequested = false;
    // Register custom hotkey listener
    scriptInterface.executionOwner.RegisterInputListener(this, WeaponInspectionAction());
}

@addMethod(ReadyEvents)
protected func OnDetach(const stateContext: ref<StateContext>, const scriptInterface: ref<StateGameScriptInterface>) -> Void {
    scriptInterface.executionOwner.UnregisterInputListener(this);
}


// Hack OnTick to play IdleBreak and SafeAction 
@replaceMethod(ReadyEvents)
protected final func OnTick(timeDelta: Float, stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let animFeature: ref<AnimFeature_WeaponHandlingStats>;
    let ownerID: EntityID;
    let statsSystem: ref<StatsSystem>;
    let gameInstance: GameInstance = scriptInterface.GetGame();
    let currentTime: Float = EngineTime.ToFloat(GameInstance.GetSimTime(gameInstance));
    let behindCover: Bool = NotEquals(GameInstance.GetSpatialQueriesSystem(gameInstance).GetPlayerObstacleSystem().GetCoverDirection(scriptInterface.executionOwner), IntEnum(0l));
    if behindCover {
        this.m_timeStamp = currentTime;
        stateContext.SetPermanentFloatParameter(n"TurnOffPublicSafeTimeStamp", this.m_timeStamp, true);
    };

    let uiSystem = GameInstance.GetBlackboardSystem(gameInstance).Get(GetAllBlackboardDefs().UI_System);
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;

    // New values for hotkey based checks
    let pressed: Bool;
    let released: Bool;
    let hold: Bool;

  // New logic
    if DefaultTransition.HasRightWeaponEquipped(scriptInterface) {

        // HOTKEY BASED
        pressed = uiSystem.GetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyPressed);
        released = uiSystem.GetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyReleased);
        hold = uiSystem.GetBool(GetAllBlackboardDefs().UI_System.FirstEqHotkeyHold);

        // Force weapon ready state if requested
        if this.readyStateRequested {
            this.readyStateRequested = false;
            scriptInterface.SetAnimationParameterFloat(n"safe", 0.0);
        };

        // Action detected when in IDLE state -> PREPARING
        if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.IDLE) && pressed {
            playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.PREPARING;
        } else {
            // Action detected when in PREPARING STATE -> TAPPED OR HOLD_STARTED
            if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.PREPARING) {
                if hold {
                    playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.HOLD_STARTED;
                } else {
                    if released {
                        playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.TAPPED;
                    };
                };
            };
        };

        // Action detected when in HOLD_STARTED state -> HOLD_ENDED
        let buttonReleased: Bool = released || scriptInterface.GetActionValue(WeaponInspectionAction()) < 0.50;
        if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.HOLD_STARTED) && buttonReleased {
            playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.HOLD_ENDED;
        };

        // RUN ANIMATIONS
        if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.PREPARING) {
            // Switch weapon state to ready when hotkey clicked
            this.readyStateRequested = true;
        };
        // Single tap
        if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.TAPPED) {
            this.savedIdleTimestamp = currentTime;
            playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.IDLE;
        } else {
            // Hold started
            if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.HOLD_STARTED) && !this.isHoldActive {

                // Move weapon to safe position and run SafeAction
                scriptInterface.SetAnimationParameterFloat(n"safe", 1.0);
                scriptInterface.PushAnimationEvent(n"SafeAction");
                stateContext.SetPermanentBoolParameter(n"TriggerHeld", true, true);
                this.safeAnimFeature.triggerHeld = true;
                this.isHoldActive = true;
            };
            // Hold released
            if Equals(playerPuppet.firstEqHotkeyState, FirstEquipHotkeyState.HOLD_ENDED) {
                stateContext.SetPermanentBoolParameter(n"TriggerHeld", false, true);
                this.safeAnimFeature.triggerHeld = false;
                playerPuppet.firstEqHotkeyState = FirstEquipHotkeyState.IDLE;
                this.isHoldActive = false;
                // Switch weapon state to ready when SafeAction completed
                this.readyStateRequested = true;
                stateContext.SetConditionFloatParameter(n"ForceSafeTimeStampToAutoUnequip", stateContext.GetConditionFloat(n"ForceSafeTimeStampToAutoUnequip") + this.GetStaticFloatParameterDefault("addedTimeToAutoUnequipAfterSafeAction", 0.00), true);
            };
        };
        // AnimFeature setup
        stateContext.SetConditionFloatParameter(n"ForceSafeCurrentTimeToAutoUnequip", stateContext.GetConditionFloat(n"ForceSafeCurrentTimeToAutoUnequip") + timeDelta, true);
        this.safeAnimFeature.safeActionDuration = TDB.GetFloat(this.weaponObjectId + t".safeActionDuration");
        scriptInterface.SetAnimationParameterFeature(n"SafeAction", this.safeAnimFeature);
        scriptInterface.SetAnimationParameterFeature(n"SafeAction", this.safeAnimFeature, DefaultTransition.GetActiveWeapon(scriptInterface));
    
    };

    if this.IsHeavyWeaponEmpty(scriptInterface) && !stateContext.GetBoolParameter(n"requestHeavyWeaponUnequip", true) {
        stateContext.SetPermanentBoolParameter(n"requestHeavyWeaponUnequip", true, true);
    };
    statsSystem = GameInstance.GetStatsSystem(gameInstance);
    ownerID = scriptInterface.ownerEntityID;
    animFeature = new AnimFeature_WeaponHandlingStats();
    animFeature.weaponRecoil = statsSystem.GetStatValue(Cast<StatsObjectID>(ownerID), gamedataStatType.RecoilAnimation);
    animFeature.weaponSpread = statsSystem.GetStatValue(Cast<StatsObjectID>(ownerID), gamedataStatType.SpreadAnimation);
    scriptInterface.SetAnimationParameterFeature(n"WeaponHandlingData", animFeature, scriptInterface.executionOwner);
}


// Always Trigger FirstEquip animation
@addMethod(PlayerPuppet)
public func HasAnyWeaponEquippedEQ() -> Bool {
    let transactionSystem: ref<TransactionSystem> = GameInstance.GetTransactionSystem(this.GetGame());
    let weapon: ref<WeaponObject> = transactionSystem.GetItemInSlot(this, t"AttachmentSlots.WeaponRight") as WeaponObject;
    let weaponId: ItemID;
    if IsDefined(weapon) {
        weaponId = weapon.GetItemID();
        if transactionSystem.HasTag(this, WeaponObject.GetMeleeWeaponTag(), weaponId) 
        || transactionSystem.HasTag(this, WeaponObject.GetOneHandedRangedWeaponTag(), weaponId)
        || transactionSystem.HasTag(this, WeaponObject.GetRangedWeaponTag(), weaponId)
        || WeaponObject.IsFists(weaponId) 
        || WeaponObject.IsCyberwareWeapon(weaponId) {
            return true;
        };
    };
    return false;
}

// Climb
@wrapMethod(ClimbEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
    if IsDefined(playerPuppet) {
        playerPuppet.SetSkipFirstEquipEQ(true);
    };
}

// Ladder
@wrapMethod(LadderEvents)
public func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    wrappedMethod(stateContext, scriptInterface);
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
    if IsDefined(playerPuppet) {
        playerPuppet.SetSkipFirstEquipEQ(true);
    };
}

// Body carrying
@wrapMethod(CarriedObjectEvents)
protected func OnEnter(stateContext: ref<StateContext>, scriptInterface: ref<StateGameScriptInterface>) -> Void {
    let carrying: Bool = scriptInterface.localBlackboard.GetBool(GetAllBlackboardDefs().PlayerStateMachine.Carrying);
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.executionOwner as PlayerPuppet;
    let hasWeaponEquipped: Bool = playerPuppet.HasAnyWeaponEquippedEQ();
    if IsDefined(playerPuppet) && !carrying {
        playerPuppet.SetSkipFirstEquipEQ(hasWeaponEquipped);
    };
    wrappedMethod(stateContext, scriptInterface);
}

// Interaction
@wrapMethod(InteractiveDevice)
protected cb func OnInteractionUsed(evt: ref<InteractionChoiceEvent>) -> Bool {
    let playerPuppet: ref<PlayerPuppet> = evt.activator as PlayerPuppet;
    let className: CName;
    let hasWeaponEquipped: Bool;
    if IsDefined(playerPuppet) {
        className = evt.hotspot.GetClassName();
        if Equals(className, n"AccessPoint") || Equals(className, n"Computer") || Equals(className, n"Stillage") || Equals(className, n"WeakFence") {
            hasWeaponEquipped = playerPuppet.HasAnyWeaponEquippedEQ();
            playerPuppet.SetSkipFirstEquipEQ(hasWeaponEquipped);
        };
    };
    wrappedMethod(evt);
}

// Takedown
@replaceMethod(gamestateMachineComponent)
protected cb func OnStartTakedownEvent(startTakedownEvent: ref<StartTakedownEvent>) -> Bool {
    let instanceData: StateMachineInstanceData;
    let initData: ref<LocomotionTakedownInitData> = new LocomotionTakedownInitData();
    let addEvent: ref<PSMAddOnDemandStateMachine> = new PSMAddOnDemandStateMachine();
    let record1HitDamage: ref<Record1DamageInHistoryEvent> = new Record1DamageInHistoryEvent();
    let playerPuppet: ref<PlayerPuppet>;
    initData.target = startTakedownEvent.target;
    initData.slideTime = startTakedownEvent.slideTime;
    initData.actionName = startTakedownEvent.actionName;
    instanceData.initData = initData;
    addEvent.stateMachineName = n"LocomotionTakedown";
    addEvent.instanceData = instanceData;
    let owner: wref<Entity> = this.GetEntity();
    owner.QueueEvent(addEvent);
    if IsDefined(startTakedownEvent.target) {
        record1HitDamage.source = owner as GameObject;
        startTakedownEvent.target.QueueEvent(record1HitDamage);
    };
    playerPuppet = owner as PlayerPuppet;
    if IsDefined(playerPuppet) {
        playerPuppet.SetSkipFirstEquipEQ(true);
    };
}

@replaceMethod(EquipmentBaseTransition)
protected final const func HandleWeaponEquip(scriptInterface: ref<StateGameScriptInterface>, stateContext: ref<StateContext>, stateMachineInstanceData: StateMachineInstanceData, item: ItemID) -> Void {
    let animFeatureMeleeData: ref<AnimFeature_MeleeData>;
    let autoRefillEvent: ref<SetAmmoCountEvent>;
    let autoRefillRatio: Float;
    let magazineCapacity: Uint32;
    let statsEvent: ref<UpdateWeaponStatsEvent>;
    let weaponEquipEvent: ref<WeaponEquipEvent>;
    let animFeature: ref<AnimFeature_EquipUnequipItem> = new AnimFeature_EquipUnequipItem();
    let weaponEquipAnimFeature: ref<AnimFeature_EquipType> = new AnimFeature_EquipType();
    let transactionSystem: ref<TransactionSystem> = scriptInterface.GetTransactionSystem();
    let statSystem: ref<StatsSystem> = scriptInterface.GetStatsSystem();
    let mappedInstanceData: InstanceDataMappedToReferenceName = this.GetMappedInstanceData(stateMachineInstanceData.referenceName);
    let itemObject: wref<WeaponObject> = transactionSystem.GetItemInSlot(scriptInterface.executionOwner, TDBID.Create(mappedInstanceData.attachmentSlot)) as WeaponObject;
    let playerPuppet: ref<PlayerPuppet> = scriptInterface.owner as PlayerPuppet;
    if TweakDBInterface.GetBool(t"player.weapon.enableWeaponBlur", false) {
        this.GetBlurParametersFromWeapon(scriptInterface);
    };

    let firstEquip: Bool = true;
    weaponEquipAnimFeature.firstEquip = true;
    stateContext.SetConditionBoolParameter(n"firstEquip", true, true);
    if playerPuppet.ShouldSkipFirstEquipEQ() {
        firstEquip = false;
        weaponEquipAnimFeature.firstEquip = false;
        stateContext.SetConditionBoolParameter(n"firstEquip", false, true);
        playerPuppet.SetSkipFirstEquipEQ(false);
    };

    scriptInterface.localBlackboard.SetBool(GetAllBlackboardDefs().PlayerStateMachine.IsWeaponFirstEquip, firstEquip);
    animFeature.stateTransitionDuration = statSystem.GetStatValue(Cast<StatsObjectID>(itemObject.GetEntityID()), gamedataStatType.EquipDuration);
    animFeature.itemState = 1;
    animFeature.itemType = TweakDBInterface.GetItemRecord(ItemID.GetTDBID(item)).ItemType().AnimFeatureIndex();
    this.BlockAimingForTime(stateContext, scriptInterface, animFeature.stateTransitionDuration + 0.10);
    weaponEquipAnimFeature.equipDuration = this.GetEquipDuration(scriptInterface, stateContext, stateMachineInstanceData);
    weaponEquipAnimFeature.unequipDuration = this.GetUnequipDuration(scriptInterface, stateContext, stateMachineInstanceData);
    scriptInterface.SetAnimationParameterFeature(mappedInstanceData.itemHandlingFeatureName, animFeature, scriptInterface.executionOwner);
    scriptInterface.SetAnimationParameterFeature(n"equipUnequipItem", animFeature, itemObject);
    weaponEquipEvent = new WeaponEquipEvent();
    weaponEquipEvent.animFeature = weaponEquipAnimFeature;
    weaponEquipEvent.item = itemObject;
    scriptInterface.executionOwner.QueueEvent(weaponEquipEvent);
    if itemObject.WeaponHasTag(n"Throwable") && !scriptInterface.GetStatPoolsSystem().HasStatPoolValueReachedMax(Cast<StatsObjectID>(itemObject.GetEntityID()), gamedataStatPoolType.ThrowRecovery) {
        animFeatureMeleeData = new AnimFeature_MeleeData();
        animFeatureMeleeData.isThrowReloading = true;
        scriptInterface.SetAnimationParameterFeature(n"MeleeData", animFeatureMeleeData);
    };
    scriptInterface.executionOwner.QueueEventForEntityID(itemObject.GetEntityID(), new PlayerWeaponSetupEvent());
    statsEvent = new UpdateWeaponStatsEvent();
    scriptInterface.executionOwner.QueueEventForEntityID(itemObject.GetEntityID(), statsEvent);
    if weaponEquipAnimFeature.firstEquip {
        scriptInterface.SetAnimationParameterFloat(n"safe", 0.00);
        stateContext.SetPermanentBoolParameter(n"WeaponInSafe", false, true);
        stateContext.SetPermanentFloatParameter(n"TurnOffPublicSafeTimeStamp", EngineTime.ToFloat(GameInstance.GetSimTime(scriptInterface.owner.GetGame())), true);
    } else {
        if stateContext.GetBoolParameter(n"InPublicZone", true) {
        } else {
            if stateContext.GetBoolParameter(n"WeaponInSafe", true) {
            scriptInterface.SetAnimationParameterFloat(n"safe", 1.00);
            };
        };
    };
    autoRefillRatio = statSystem.GetStatValue(Cast<StatsObjectID>(itemObject.GetEntityID()), gamedataStatType.MagazineAutoRefill);
    if autoRefillRatio > 0.00 {
        magazineCapacity = WeaponObject.GetMagazineCapacity(itemObject);
        autoRefillEvent = new SetAmmoCountEvent();
        autoRefillEvent.ammoTypeID = WeaponObject.GetAmmoType(itemObject);
        autoRefillEvent.count = Cast<Uint32>(Cast<Float>(magazineCapacity) * autoRefillRatio);
        itemObject.QueueEvent(autoRefillEvent);
    };

    if playerPuppet.ShouldSkipFirstEquipEQ() {
        playerPuppet.SetSkipFirstEquipEQ(false);
    };
}

