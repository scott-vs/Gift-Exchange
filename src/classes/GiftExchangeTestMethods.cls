@isTest
private class GiftExchangeTestMethods{


   static testMethod void createNewPool(){
        Profile p = [select id from profile where name='Standard User'];
        Profile p2 = [select id from profile where name='Chatter Free User'];
        
        User u = new User(alias = 'testu000', email='testtest000@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest000', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest000@testorg.com');
        
         // Create new users
        
        List<User> newUsers = new List<User>();
        User u1 = new User(alias = 'testu001', email='testtest001@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest001', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest001@testorg.com');
        newUsers.add(u1);
        User u2 = new User(alias = 'testu002', email='testtest002@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest002', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest002@testorg.com');
        newUsers.add(u2);
        User u3 = new User(alias = 'testu003', email='testtest003@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest003', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p2.Id, 
            timezonesidkey='America/Los_Angeles', username='testtest003@testorg.com');
        newUsers.add(u3);
        User u4 = new User(alias = 'testu004', email='testtest004@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest003', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p2.Id, 
            timezonesidkey='America/Los_Angeles', username='testtest004@testorg.com');
        newUsers.add(u4);
        User u5 = new User(alias = 'testu005', email='testtest005@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest005', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest005@testorg.com');
        newUsers.add(u5);
        
        insert newUsers;
        
        Test.startTest();
       
        GiftExchangeCronJobs.clearAll();
        GiftExchangeController controller = new GiftExchangeController();
        System.assertEquals(true,controller.getNeedNewPool());
        System.assertEquals(false, controller.getStep1Setup());
        System.assertEquals(false, controller.getStep2Setup());
        
        
        controller.nextPage();
        
        
        // Navigation
        System.assertEquals(true, controller.getStep1Setup());
        controller.prevPage();
        System.assertEquals(false, controller.getStep1Setup());
        
        // Page 1 Setup
        controller.nextPage();
        Date n = date.today();
        System.assertEquals('Secret Santa '+n.year(), controller.dummyPool.name);
        controller.dummyPool.name = 'Testing Pool';
        controller.dummyPool.Moderator_Name__c = 'Testing testerson';
        controller.dummyPool.Gift_Giving_Time__c = n.addMonths(1);
        
        // Page 2 Setup
        controller.nextPage();
        System.assertEquals(true, controller.getStep2Setup());
        System.assertEquals('2', controller.deadlinePick);
        controller.deadlinePick = '1';
        controller.createNewPool();
        
       
        // Reset
        controller = new GiftExchangeController();
        System.assertEquals(1, controller.myPools.size());
        GiftExchangeController.PoolClass myPool = controller.myPools[0];
        
        System.assertEquals(true, controller.myPools[0].getShowAdminPanel());
        //System.assertEquals(true, controller.myPools[0].getShowSFPanel());
        //System.assertEquals(true, controller.getNeedToAttach());
        //System.assertEquals(false,controller.getNeedToSignUp());
        //System.assertEquals(n.addMonths(1), controller.ownedPool.Gift_Giving_Time__c);
        //System.assertEquals(n.addMonths(1).addDays(-7), controller.ownedPool.Sign_Up_Date__c);
        //System.assertEquals(controller.myPool[0].getDeadline(), controller.myPool[0].myPool.Sign_Up_Date__c.format());
        //System.assertEquals(controller.getExchangeDate(), controller.ownedPool.Gift_Giving_Time__c.format());
        //System.assertEquals(false, controller.getNamesDrawn());
       
        //System.assertEquals(true,controller.getIsSignedUp());
        System.assertEquals('your pick', myPool.getPick());
        System.assertEquals('Invite your coworkers to join the group on Chatter or add them to the group yourself.', myPool.getInviteMessage());
        System.assertEquals('Testing Pool',myPool.myPool.name);
       
//        System.assertEquals(controller.orgPool.Chatter_Group__c, controller.getOrgPoolGroupId());
        
        
        
        System.runAs(u1){
            controller = new GiftExchangeController();
         //   System.assertEquals(false,controller.getNeedNewPool());
         //   System.assertEquals(true,controller.getNeedToSignUp());
         //   System.assertEquals(false,controller.getIsSignedUp());
           
        }
        
        List<CollaborationGroupMember> members = new List<CollaborationGroupMember>();
        members.add(new CollaborationGroupMember(CollaborationGroupId = myPool.myPool.Chatter_Group__c, MemberId = u1.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = myPool.myPool.Chatter_Group__c, MemberId = u2.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = myPool.myPool.Chatter_Group__c, MemberId = u3.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = myPool.myPool.Chatter_Group__c, MemberId = u4.id));
        insert members;
        
        // reset again 
        controller = new GiftExchangeController();
        myPool = controller.myPools[0];
        Integer okPickSize = myPool.okPicks.size();
        System.assertEquals(0, myPool.notOkPicks.size());
        
        System.debug('ok picks: ' + myPool.okPicks);
        System.debug('notok picks: ' + myPool.notOkPicks);
        myPool.partSelect = u1.id;
        myPool.excludePart();
        System.assertEquals(okPickSize - 1, myPool.okPicks.size());
        System.assertEquals(1, myPool.notOkPicks.size());
        
        myPool.partSelect = u2.id;
        myPool.excludePart();
        System.assertEquals(okPickSize - 2, myPool.okPicks.size());
        System.assertEquals(2, myPool.notOkPicks.size());
        myPool.partSelect = u3.id;
        myPool.excludePart();
        System.assertEquals(okPickSize - 3, myPool.okPicks.size());
        System.assertEquals(3, myPool.notOkPicks.size());
        myPool.partSelect = u4.id; // At max of three people.
        myPool.excludePart();
        System.assertEquals(okPickSize - 3, myPool.okPicks.size());
        System.assertEquals(3, myPool.notOkPicks.size());
        
        
        myPool.excludeSelect = u1.id;
        myPool.includePart();
        System.assertEquals(okPickSize - 2, myPool.okPicks.size());
        System.assertEquals(2, myPool.notOkPicks.size());
        
        myPool.partSelect = u2.id; // over 25%, so no go
        myPool.excludePart();
        
        
        myPool.myPool.Sign_Up_Date__c = n;
        myPool.changeSettings();
        
        System.runAs(u1){
            controller = new GiftExchangeController();
            myPool = controller.myPools[0];
        
            //System.assertEquals(false,controller.getNeedToSignUp());
            System.assertEquals('Invite your coworkers to join the group on Chatter.', myPool.getInviteMessage());
        
        }
        
        GiftExchangeCronJobs.pickNamesFromHat();
      
        Test.stopTest();
        
        
        
    }
    
    
     static testMethod void afterNamesArePicked() {
        Profile p = [select id from profile where name='Standard User'];
        Profile p2 = [select id from profile where name='Chatter Free User'];
        
        GiftExchangeCronJobs.clearAll();
        
        // set up new org
        GiftExchangeController controller = new GiftExchangeController();
        controller.getNeedNewPool();
        controller.nextPage();
        Date n = date.today();
        controller.dummyPool.name = 'Testing Pool';
        controller.dummyPool.Gift_Giving_Time__c = n.addMonths(1);
        controller.nextPage();
        controller.deadlinePick = '1';
        controller.createNewPool();
        controller = new GiftExchangeController();
        controller.myPools[0].myPool.Names_Drawn__c = true;
        update controller.myPools[0].myPool;
        
        // delete it 
        controller.deletePool();
        
        
        // set up new org again
        controller = new GiftExchangeController();
        controller.getNeedNewPool();
        controller.nextPage();
        n = date.today();
        controller.dummyPool.name = 'Testing Pool 2';
        controller.dummyPool.Gift_Giving_Time__c = n.addMonths(1);
        controller.nextPage();
        controller.deadlinePick = '1';
        controller.createNewPool();
        controller = new GiftExchangeController();
    
        List<User> newUsers = new List<User>();
        User u1 = new User(alias = 'testu001', email='testtest001@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest001', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest001@testorg.com');
        newUsers.add(u1);
        User u2 = new User(alias = 'testu002', email='testtest002@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest002', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest002@testorg.com');
        newUsers.add(u2);
        User u3 = new User(alias = 'testu003', email='testtest003@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest003', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p2.Id, 
            timezonesidkey='America/Los_Angeles', username='testtest003@testorg.com');
        newUsers.add(u3);
        User u4 = new User(alias = 'testu004', email='testtest004@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest003', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p2.Id, 
            timezonesidkey='America/Los_Angeles', username='testtest004@testorg.com');
        newUsers.add(u4);
        User u5 = new User(alias = 'testu005', email='testtest005@testorg.com',
            emailencodingkey='UTF-8', lastname='testtest005', languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='testtest005@testorg.com');
        newUsers.add(u5);
        
        insert newUsers;
        
       
        
        CollaborationGroup chatterGroup = new CollaborationGroup(CollaborationType = 'Private');
        chatterGroup.name = 'Private group test 001';
        chatterGroup.InformationBody = controller.myPools[0].myPool.id + ':' + u4.id;
                         
        insert chatterGroup;

        List<CollaborationGroupMember> members = new List<CollaborationGroupMember>();
        members.add(new CollaborationGroupMember(CollaborationGroupId = controller.myPools[0].myPool.Chatter_Group__c, MemberId = u1.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = controller.myPools[0].myPool.Chatter_Group__c, MemberId = u2.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = controller.myPools[0].myPool.Chatter_Group__c, MemberId = u3.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = controller.myPools[0].myPool.Chatter_Group__c, MemberId = u4.id));
        members.add(new CollaborationGroupMember(CollaborationGroupId = chatterGroup.id, MemberId = u3.id));
        insert members;
        
        
        List<Gift_Exchange_Participant__c> participants = new List<Gift_Exchange_Participant__c>();
        participants.add(new Gift_Exchange_Participant__c(Gift_Exchange_Pool__c =controller.myPools[0].myPool.id, Participant__c = u1.id, Selection__c = u2.id));
        participants.add(new Gift_Exchange_Participant__c(Gift_Exchange_Pool__c =controller.myPools[0].myPool.id, Participant__c = u3.id, Selection__c = u4.id));
        
        insert participants;
        
        controller.myPools[0].myPool.Names_Drawn__c = true;
        update controller.myPools[0].myPool;
        
        System.runAs(u1){
        
            controller = new GiftExchangeController();
            System.assertEquals('testtest002', controller.myPools[0].getPick());
            System.assertEquals('/_ui/common/search/client/ui/ChatterSearchResultsPage?searchType=2&str=Hey+testtest002%21', controller.myPools[0].getResponseLink());
            System.assertEquals(u2.id, controller.myPools[0].getPickUrl());
            //System.assertEquals(true, controller.getNamesDrawn());
        
            controller.myPools[0].getPickPic();
            
            
            controller.myPools[0].iGotGift = true;
            controller.myPools[0].setGiftGot();
            controller.myPools[0].myAnonMessage = 'Testing anon message';
            controller.myPools[0].sendMess();
        }
        
        System.runAs(u5){
        
            controller = new GiftExchangeController();
            
            //System.assertEquals(true, controller.getMissedDeadline());
            
        
        }
        
        System.runAs(u3){
            List<FeedItem> posts = new List<FeedItem>();
            
            FeedItem post = new FeedItem();
            post.parentId = chatterGroup.id;
            post.body = 'I would like to know: testing';
            posts.add(post);
            post = new FeedItem();
            post.parentId = chatterGroup.id;
            post.body = 'I got my gift.';
            posts.add(post);
            
            insert posts;
        }
        
                 
        GiftExchangeCronJobs.dailyCheck();
    
    
    }
    
    


}