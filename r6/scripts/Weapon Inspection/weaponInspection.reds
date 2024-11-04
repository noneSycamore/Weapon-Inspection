module WeaponInspection
// Refers to Always First Equip mod

private static func WeaponInspectionAction() -> CName = n"WeaponInspection" 

public class WeaponInspectionInputListener {
    private let m_player: wref<PlayerPuppet>;
    // Replace with true if you want to use Other Animation instead of FirstEquip animation
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
        let itemID: ItemID;
        if !IsDefined(this.m_player) {
            return false;
        }

        if Equals(ListenerAction.GetName(action), WeaponInspectionAction()) && Equals(ListenerAction.GetType(action), gameinputActionType.BUTTON_PRESSED) {
            itemID = equipmentSystemData.GetSlotActiveItem(EquipmentManipulationRequestSlot.Right);
            if itemID.IsValid() {
                if !transactionSystem.HasTag(this.m_player, n"MeleeWeapon", itemID) && this.ifOtherAnim {
                    AnimationControllerComponent.PushEvent(this.m_player, this.animationName);
                    return true;
                }
                equipmentSystemData.RemoveItemFromSlotActiveItem(itemID);
            } else {
                itemID = equipmentSystemData.GetLastUsedItemID(ELastUsed.Weapon);
            }
            this.m_player.SetSkipFirstEquipEQ(false);
            drawItemRequest = new DrawItemRequest();
            drawItemRequest.itemID = itemID;
            drawItemRequest.owner = this.m_player;
            equipmentSystem.QueueRequest(drawItemRequest);
        }
    }
}

@addField(PlayerPuppet) let WeaponInspectionInputListener: ref<WeaponInspectionInputListener>;
@addField(PlayerPuppet) let skipFirstEquip: Bool;

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