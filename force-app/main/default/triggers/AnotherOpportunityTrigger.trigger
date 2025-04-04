/*
AnotherOpportunityTrigger Overview

This trigger was initially created for handling various events on the Opportunity object. It was developed by a prior developer and has since been noted to cause some issues in our org.

IMPORTANT:
- This trigger does not adhere to Salesforce best practices.
- It is essential to review, understand, and refactor this trigger to ensure maintainability, performance, and prevent any inadvertent issues.

ISSUES:
Avoid nested for loop - 1 instance - done
Avoid DML inside for loop - 1 instance - done
Bulkify Your Code - 1 instance - done
Avoid SOQL Query inside for loop - 2 instances
Stop recursion - 1 instance

RESOURCES: 
https://www.salesforceben.com/12-salesforce-apex-best-practices/
https://developer.salesforce.com/blogs/developer-relations/2015/01/apex-best-practices-15-apex-commandments
*/
trigger AnotherOpportunityTrigger on Opportunity (before insert, after insert, before update, after update, before delete, after delete, after undelete) {
    if (Trigger.isBefore){
        if (Trigger.isInsert){
            // Set default Type for new Opportunities
            Opportunity opp = Trigger.new[0];
            if (opp.Type == null){
                opp.Type = 'New Customer';
            }        
        } else if (Trigger.isDelete){
            // Prevent deletion of closed Opportunities
            for (Opportunity oldOpp : Trigger.old){
                if (oldOpp.IsClosed){
                    oldOpp.addError('Cannot delete closed opportunity');
                }
            }
        }
    }

    if (Trigger.isAfter){
        if (Trigger.isInsert){
            // Create a new Task for newly inserted Opportunities
            List<Task> taskList = new List<Task>();
            for (Opportunity opp : Trigger.new){
                Task tsk = new Task();
                tsk.Subject = 'Call Primary Contact';
                tsk.WhatId = opp.Id;
                tsk.WhoId = opp.Primary_Contact__c;
                tsk.OwnerId = opp.OwnerId;
                tsk.ActivityDate = Date.today().addDays(3);

                //Bulkification of code.
                taskList.add(tsk);
            }
            //Moving DML statement outside of the for loop.
            insert taskList;
        } 
        // Send email notifications when an Opportunity is deleted 
        else if (Trigger.isDelete){
            notifyOwnersOpportunityDeleted(Trigger.old);
        } 
        // Assign the primary contact to undeleted Opportunities
        else if (Trigger.isUndelete){
            assignPrimaryContact(Trigger.newMap);
        }
    }

    if (Trigger.isBefore) {
        if (Trigger.isUpdate) {
            // Append Stage changes in Opportunity Description
            for (Opportunity opp : Trigger.new){
                //Removing a nested for loop.
                if (opp.StageName != null){
                    opp.Description += '\n Stage Change:' + opp.StageName + ':' + DateTime.now().format();
                }          
            }
        }
    }

    /*
    notifyOwnersOpportunityDeleted:
    - Sends an email notification to the owner of the Opportunity when it gets deleted.
    - Uses Salesforce's Messaging.SingleEmailMessage to send the email.
    */
    private static void notifyOwnersOpportunityDeleted(List<Opportunity> opps) {
        //Collect all owner ids in a set.
        Set<Id> opportunityOwnerIdSet = new Set<Id>();
        for (Opportunity opportunity : opps) {
            opportunityOwnerIdSet.add(opportunity.OwnerId);
        }

        //Removing a SOQL statement from within a for loop.
        List<User> userList = [SELECT Id, Email FROM User WHERE Id IN :opportunityOwnerIdSet];
        List<String> toAddresses = new List<String>();

        for (User user : userList) {
            toAddresses.add(user.Email);
        }

        List<Messaging.SingleEmailMessage> mails = new List<Messaging.SingleEmailMessage>();
        for (Opportunity opp : opps){
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(toAddresses);
            mail.setSubject('Opportunity Deleted : ' + opp.Name);
            mail.setPlainTextBody('Your Opportunity: ' + opp.Name +' has been deleted.');
            mails.add(mail);
        }        
        
        try {
            Messaging.sendEmail(mails);
        } catch (Exception e){
            System.debug('Exception: ' + e.getMessage());
        }
    }

    /*
    assignPrimaryContact:
    - Assigns a primary contact with the title of 'VP Sales' to undeleted Opportunities.
    - Only updates the Opportunities that don't already have a primary contact.
    */
    private static void assignPrimaryContact(Map<Id,Opportunity> oppNewMap) {    

        Set<Id> accountIdSet = new Set<Id>();
        for (Opportunity opp : oppNewMap.values()) {
            accountIdSet.add(opp.AccountId);
        }

        List<Contact> contactList = [ SELECT Id, FirstName, LastName, AccountId 
                                        FROM Contact 
                                        WHERE AccountId IN :accountIdSet AND Title = 'VP Sales'];
        Map<Id, Contact> accountIdToContactMap = new Map<Id, Contact>();

        for (Contact con : contactList) {
            accountIdToContactMap.put(con.AccountId, con);
        }


        Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>();
        for (Opportunity opp : oppNewMap.values()){            
            if (opp.Primary_Contact__c == null){
                Contact con = accountIdToContactMap.get(opp.AccountId);
                Opportunity oppToUpdate = new Opportunity(Id = opp.Id);
                oppToUpdate.Primary_Contact__c = con.Id;
                oppMap.put(opp.Id, oppToUpdate);
            }
        }
        update oppMap.values();
    }
}