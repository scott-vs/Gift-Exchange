/*
    Class handles all actions done by the daily cron job
    outside of the Gift Exhcange tab controller.
*/
global class GiftExchangeCronJobs{
    // Change for an unmanaged package.
    public static string TAB_URL = '/apex/gift__GiftExchange'; //  = '/apex/GiftExchange';
    
    // Deletes all pools in the system.
    public static void clearAll(){
        List<Gift_Exchange_Pool__c> pools = [select id, Chatter_Group__c, Cron_Job_1__c, Cron_Job_2__c, Names_Drawn__c, Moderator__c FROM Gift_Exchange_Pool__c LIMIT 200];
        List<Id> groupsToDelete = new List<Id>();
        for (Gift_Exchange_Pool__c pool : pools){
            if (!Test.isRunningTest()) {
                System.abortJob(pool.Cron_Job_2__c);
            }
            groupsToDelete.add(pool.Chatter_Group__c);
        }
        if (Gift_Exchange_Pool__c.SObjectType.getDescribe().isDeletable()) {
            delete pools;
        }
        if (CollaborationGroup.SObjectType.getDescribe().isDeletable()) {
            delete [select id from CollaborationGroup WHERE id = : groupsToDelete];
        }
    }
    
    
    // Formats how a message should look when posted to Chatter.
    public static String GiftExchangeChatter(String msg){
        String line = '';
        String s = '.\n';
        s += line;
        s += msg + '\n';
        s += line;
        
        return s;
    
    }
    
    
    // Class helps store the exclude list
    private class ExcludeList{
        private Map<String, Set<String>> masterList;
        public ExcludeList(){
            this.masterList = new Map<String, Set<String>>();
        }
        
        
        public void add(String s1, String s2){
            Set<String> myExList = this.masterList.get(s1);
            if (myExList == null){
                myExList = new Set<String>();
                this.masterList.put(s1, myExList);
            }
            myExList.add(s2);
            
        }
        
        // comes back true if person 1 is cool with person 2
        public Boolean isCoolWith(String s1, String s2){
            if (s1 == s2) // same dude
                return false;
            if (this.masterList.get(s1) == null) // cool with anyone
                return true;
            if (this.masterList.get(s1).contains(s2)) // they got beef
                return false;
            return true;
        }
    }
    
    // Functions attempts to swap a selection with another participant.
    private static Boolean tryToSwap(Gift_Exchange_Participant__c p, Set<Gift_Exchange_Participant__c> poolPrime, String thisId, ExcludeList exList){
        Set<Gift_Exchange_Participant__c> pool = new Set<Gift_Exchange_Participant__c>();
        pool.addAll(poolPrime);
        pool.remove(p);
        for (Gift_Exchange_Participant__c partFromPool : pool){
            String partFromPoolSel = partFromPool.Selection__c;
            if (exList.isCoolWith(p.Participant__c, partFromPoolSel)){
                if (exList.isCoolWith(partFromPool.Participant__c, thisId)){
                    p.Selection__c = partFromPoolSel;
                    partFromPool.Selection__c = thisId;
                    return true;
                }else if (tryToSwap(partFromPool, pool, thisId, exList)){
                    p.Selection__c = partFromPoolSel;
                    return true;
                }
            }
        
        }
        return false;
    }
    
    // Main function for drawing names.
    public static void pickNamesFromHat(){
        
        List<Gift_Exchange_Pool__c> pools = [SELECT id, Chatter_Group__c, Name, Cron_Job_1__c, OwnerId, ExcludeList__c, Moderator__c
                                     FROM Gift_Exchange_Pool__c
                                     WHERE Names_Drawn__c = false
                                       AND Sign_Up_Date__c <= : Date.today()];
          
        for (Gift_Exchange_Pool__c pool : pools){
            ExcludeList exList = new ExcludeList();
            List<CollaborationGroupMember> groupMembers = [SELECT MemberId 
                                                            FROM CollaborationGroupMember 
                                                            WHERE CollaborationGroupId =: pool.Chatter_Group__c
                                                                AND MemberId !=: pool.Moderator__c];
            
            List<Gift_Exchange_Participant__c> participants = new List<Gift_Exchange_Participant__c>();
            List<String> memberIdPool = new List<String>();
            for (CollaborationGroupMember groupMember : groupMembers){
                participants.add(new Gift_Exchange_Participant__c(Gift_Exchange_Pool__c = pool.id, Participant__c = groupMember.MemberId));
                memberIdPool.add(groupMember.MemberId);
            }
            
            Map<id, User> users = new Map<id, User> ([SELECT id, name, UserType FROM User WHERE id = :memberIdPool]);
            List<Gift_Exchange_Participant__c> chatterUsers = new List<Gift_Exchange_Participant__c>(); 
            
            // initial pick
            for (integer x = 0; x < (participants.size() - 1); x++){
                Gift_Exchange_Participant__c participant = participants.get(x);
                if (users.get(participant.Participant__c).UserType == 'CSNOnly'){
                    chatterUsers.add(participant);
                    exList.add(pool.ownerId, participant.Participant__c);
                    exList.add(participant.Participant__c, pool.ownerId);
                }
                double r; 
                do {
                    r = Math.random() * memberIdPool.size();
                } while (participant.Participant__c == memberIdPool.get(r.intValue()));
                participant.Selection__c = memberIdPool.get(r.intValue());
                memberIdPool.remove(r.intValue());
            }
            
            // initial pick - handle last user
            Gift_Exchange_Participant__c lastParticipant = participants.get(participants.size() - 1);
            if (users.get(lastParticipant.Participant__c).UserType == 'CSNOnly'){
                chatterUsers.add(lastParticipant);
                exList.add(pool.ownerId, lastParticipant.Participant__c);
                exList.add(lastParticipant.Participant__c, pool.ownerId);
            }
            if (lastParticipant.Participant__c == memberIdPool.get(0)){
                String swapId = participants.get(0).Selection__c;
                participants.get(0).Selection__c = lastParticipant.Participant__c;
                lastParticipant.Selection__c = swapId;
            } else
                lastParticipant.Selection__c = memberIdPool.get(0);
         
            // "Do Not Pick" name swap
            if (pool.ExcludeList__c != null){
                List<String> rows = pool.ExcludeList__c.split('~');
                for (String row : rows){
                    List<String> cols = row.split(':');
                    String key = cols.get(0);
                    cols.remove(0);
                    for (String col: cols)
                        exList.add(key, col);
                }
            }
            Set<Gift_Exchange_Participant__c> availForSwap = new Set<Gift_Exchange_Participant__c>();
            availForSwap.addAll(participants);
            for (Gift_Exchange_Participant__c p : participants){
                if (!exList.isCoolWith(p.Participant__c, p.Selection__c)){
                
                    tryToSwap(p, availForSwap, p.Selection__c, exList);
                }
            
            }
                
            // Add Gift_Exchange_Participant__c objects.
            insert participants;
            if (!Schema.sObjectType.Gift_Exchange_Pool__c.fields.Names_Drawn__c.isUpdateable()){
                return; 
            }
            pool.Names_Drawn__c = true;
            update pool;
            
            // Blast a Chatter post telling people that names have been drawn.
            List<FeedItem> posts = new List<FeedItem>();
            FeedItem post = new FeedItem();
            post.parentId = pool.Chatter_Group__c;
            post.body = GiftExchangeCronJobs.GiftExchangeChatter('Names have been selected!\n\n Check out the link below to see your pick!');
            post.Title = 'Your Pick for ' + pool.name;
            post.LinkUrl = TAB_URL;
            post.CreatedById = pool.Moderator__c;
            post.CreatedDate = System.now();
            posts.add(post);
            
            // Create private groups for Chatter free users to view their picks.
            integer count = 0;
            if (chatterUsers.size() > 0){
                Map<String, CollaborationGroup> groups = new Map<String, CollaborationGroup>();
                for (Gift_Exchange_Participant__c chatterUser : chatterUsers){
                   CollaborationGroup chatterGroup = new CollaborationGroup(CollaborationType = 'Private');
                   chatterGroup.name = pool.name + ' pick ' + count;
                   groups.put(chatterUser.id, chatterGroup);
                   count++;
                }
                insert groups.values();
                List<CollaborationGroupMember> members = new List<CollaborationGroupMember>();
                for (Gift_Exchange_Participant__c chatterUser : chatterUsers){
                   CollaborationGroupMember member = new CollaborationGroupMember();
                   member.CollaborationGroupId = groups.get(chatterUser.id).id;
                   member.MemberId = chatterUser.Participant__c;
                   members.add(member);
                   
                   String pickName = users.get(chatterUser.Selection__c).name;
                   groups.get(chatterUser.id).InformationTitle = 'Gift Exchange Id';
                   groups.get(chatterUser.id).InformationBody = pool.id + ':' + chatterUser.Selection__c;
                   //groups.get(chatterUser.id).Description = users.get(chatterUser.Participant__c).name +'\'s pick is ' + pickName;
                   
                   
                   String msg = 'When you have bought your gift for ' + pickName + ', please post "I have got my gift" so that I know to stop reminding you. ';
                   post = new FeedItem();
                   post.parentId = member.CollaborationGroupId;
                   post.body = GiftExchangeCronJobs.GiftExchangeChatter(msg);
                   posts.add(post);
                   
                   msg = 'To send an anonymous question to ' + pickName + ', post on this private group "I would like to know: _____" ';
                   msg += 'For example: \n\nI would like to know: What size t-shirt do you wear?';
                   post = new FeedItem();
                   post.parentId = member.CollaborationGroupId;
                   post.body = GiftExchangeCronJobs.GiftExchangeChatter(msg);
                   posts.add(post);
                   
                   msg = 'Because you are on a Chatter free account, you will not be able to access the Gift Exchange page, so here\'s how to play the game:';
                   post = new FeedItem();
                   post.parentId = member.CollaborationGroupId;
                   post.body = GiftExchangeCronJobs.GiftExchangeChatter(msg);
                   posts.add(post);
                   
                   msg = users.get(chatterUser.Participant__c).name + ', \n\n';
                   msg += 'Your pick is this gift exchange is ' + pickName + '.';
                   post = new FeedItem();
                   post.parentId = member.CollaborationGroupId;
                   post.body = GiftExchangeCronJobs.GiftExchangeChatter(msg);
                   posts.add(post);
                }
                insert members;
                post = new FeedItem();
                post.parentId = pool.Chatter_Group__c;
                post.CreatedById = pool.Moderator__c;
                post.CreatedDate = System.now();
                post.body = GiftExchangeCronJobs.GiftExchangeChatter('Chatter free members!\n\n Please check out your private group to find out your pick for this gift exchange.');
                posts.add(post);
                
                update groups.values();
            
            }
            insert posts;
            
                                        
        }

    }
    
    // Returns true if compareTo is numDays away from today.
    private static Boolean isThisDate(Integer numDays, Date compareTo){
        if (Date.today().daysBetween(compareTo) == numDays)
            return true;
        return false;
    }
    
    
    // Returns a "Wall of Shame" Chatter post for people who haven't gotten a gift yet.
    private static FeedItem whoNeedsGift(FeedItem post, Gift_Exchange_Pool__c pool, List<Gift_Exchange_Participant__c> parts){
        
        if (parts.size() != 0){
            post.body += '\n\n';
            
            for (integer x = 0; x < parts.size(); x++){
                if (x != 0)
                    post.body += ', ';
                else if (x == (parts.size() - 1))
                    post.body += ', and ';
                post.body += parts.get(x).Participant_Name__c;
            }
            post.body += ', you have not checked off that you got your gift this year.'; 
            post.Title = 'Check it off here!';
            post.LinkUrl = TAB_URL;
            post.CreatedById = pool.Moderator__c;
            post.CreatedDate = System.now();
            
        }
        return post;
    }
    
  
    
    @future(callout=true)
    public static void dailyCheck(){
        
        List<Gift_Exchange_Pool__c> pools = [SELECT id, Messages__c, Chatter_Group__c, Name, Cron_Job_1__c, Cron_Job_2__c, Names_Drawn__c, Sign_Up_Date__c, Gift_Giving_Time__c, Moderator__c
                                     FROM Gift_Exchange_Pool__c LIMIT 200];
        List<FeedItem> posts = new List<FeedItem>();
                
        List<String> poolIds = new List<String>();
        for (Gift_Exchange_Pool__c pool : pools)
            poolIds.add(pool.id);
        
        Map<String,List<Gift_Exchange_Participant__c>> parts = new Map<String,List<Gift_Exchange_Participant__c>>();
        for (Gift_Exchange_Participant__c p : [SELECT Participant_Name__c, Gift_Exchange_Pool__c FROM Gift_Exchange_Participant__c WHERE Gift_Exchange_Pool__c = : poolIds AND Got_Gift__c = false]){
            List<Gift_Exchange_Participant__c> partList = parts.get(p.Gift_Exchange_Pool__c);
            if (partList == null){
                partList = new List<Gift_Exchange_Participant__c>();
                parts.put(p.Gift_Exchange_Pool__c, partList);
            }
            partList.add(p);
        }
        
        
        
        for (Gift_Exchange_Pool__c pool : pools){
            FeedItem post = null;
            
            // Post out all the anonymous questions
            if (pool.Messages__c != null){
                for (String message : pool.Messages__c.split('#EOM')){
                    if (message.trim() != ''){
                     post = new FeedItem();
                     post.parentId = pool.Chatter_Group__c;
                     post.body = message;
                     post.CreatedById = pool.Moderator__c;
                     post.CreatedDate = System.now();
                     posts.add(post);
                    }
                }
                pool.Messages__c = '';
            }
            
            post = new FeedItem();
            post.parentId = pool.Chatter_Group__c;
            post.body = '';
            post.CreatedById = pool.Moderator__c;
            post.CreatedDate = System.now();
                     
            if (pool.Names_Drawn__c){
                if (isThisDate(-1, pool.Gift_Giving_Time__c)){
                    post.body = '.\nHope you enjoyed our gift exchange yesterday! Here is a list of everyone and their Secret Santa:\n\n';
                    for (Gift_Exchange_Participant__c part : [SELECT Participant_Name__c, Participant__c, Selection_Name__c, Selection__c FROM Gift_Exchange_Participant__c WHERE Gift_Exchange_Pool__c = : pool.id])
                        post.body += part.Selection_Name__c +  '\'s gift was given by ' + part.Participant_Name__c + '.\n';
                    
                } else if (isThisDate(1, pool.Gift_Giving_Time__c) || Test.isRunningTest()){
                    post.body = '.\nOur exchange is TOMORROW! ';
                    post = whoNeedsGift(post, pool, parts.get(pool.id));
                } else if (isThisDate(3, pool.Gift_Giving_Time__c)){
                    post.body = '.\nJust a reminder that our gift exchange is only 3 days away.';
                    post = whoNeedsGift(post, pool, parts.get(pool.id));
                } else if (isThisDate(7, pool.Gift_Giving_Time__c)){
                    post.body = '.\nOur gift exchange is taking place in ONE WEEK. If you have already gotten a gift for your pick, then please check off on your Gift Exchange page. Otherwise, we\'ll give you a friendly reminder in a few days.';
                } else if (isThisDate(14, pool.Gift_Giving_Time__c)){
                    post.body = '.\nOur gift exchange is taking place in two weeks.';
                } else if (isThisDate(-14, pool.Gift_Giving_Time__c)){
                    System.abortJob(pool.Cron_Job_2__c);
                    GiftExchangeCronJobs.clearAll();
               }
            
            } else {
                if (isThisDate(0, pool.Sign_Up_Date__c)){
                    pickNamesFromHat();
                } else if (isThisDate(1, pool.Sign_Up_Date__c) || Test.isRunningTest()){
                    post.body = '.\nJust a reminder that our deadline for signing up is TOMORROW. If you know anyone that still needs to sign up, invite them to join this group.';
                } else if (isThisDate(3, pool.Sign_Up_Date__c)){
                    post.body = '.\nJust three days left to sign up for our gift exchange. ';
                } else if (isThisDate(7, pool.Sign_Up_Date__c)){
                    post.body = '.\nOne week left to sign up.';
                }
            
            }
            
            if (post.body != '')
                posts.add(post);
        
        }
        insert posts;
        update pools;
        
    
    }

}