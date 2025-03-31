public with sharing class AccountTriggerHandler extends TriggerHandler {
    
    @TestVisible
    public override void beforeInsert(){
        AccountHelper.setTypeProspect(Trigger.new);
        AccountHelper.addressCopy(Trigger.new);
        AccountHelper.setRating(Trigger.new);
    }

    @TestVisible
    public override void afterInsert(){
        AccountHelper.defaultContact(Trigger.new);
    }
}