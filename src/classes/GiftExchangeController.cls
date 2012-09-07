/*
    Controller for the main Gift Exchange page.
    
    07/25/2012 - Submitted and passed AppExchange review.
    07/31/2012 - Catch error when user attempts to create a group with the same name.
    09/07/2012 - Documentation added.
*/

public with sharing class GiftExchangeController {
    //
    // Defaults - Change for groups who do not celebrate Christmas.
    //
    private String POOL_NAME = 'Secret Santa';
    private String MOD_NAME = 'Santa Claus';
    
    //
    // public variables
    //
    
    public List<PoolClass> myPools {get; set;}
    public Gift_Exchange_Pool__c dummyPool {get; set;}
    public String deadlinePick {get; set;}
    public String newPoolName { get; set; }
    
    //
    // private variables
    //
    private String userId;
    public Gift_Exchange_Pool__c ownedPool {get;set;}
    public Gift_Exchange_Pool__c partPool;
    private Gift_Exchange_Pool__c notAttachPool;
    private Map<String, Set<String>> excludeList;
    private Integer setupStep;
    
    private User myPick;
    
    //
    // constructor
    //
    public GiftExchangeController() {
        this.initPage();
    }
    
    
    //
    // Pool Class
    //
     public class PoolClass{
     
        // public - PoolClass
        public Gift_Exchange_Pool__c myPool {get;set;}
        public Gift_Exchange_Participant__c myParticipation {get;set;}
        public List<SelectOption> notOkPicks { get; set; }
        public String excludeSelect { get; set; }
        public List<SelectOption> okPicks { get; set; }
        public List<SelectOption> allPicks { get; set; }
        public String partSelect { get; set; }
        public Boolean iGotGift { get; set; }
        public String myAnonMessage { get; set; }
        
        // private - PoolClass
        private Map<String, Set<String>> excludeList;
        private String userId;
        private User myPick;
        
        // constructor - PoolClass
        public PoolClass(Gift_Exchange_Pool__c pool){
            this.myPool = pool;
            this.userId = UserInfo.getUserId();
            this.allPicks = new List<SelectOption>();
            this.okPicks = new List<SelectOption>();
            this.notOkPicks = new List<SelectOption>();
            
            List<String> memberList = new List<String>();
            for (CollaborationGroupMember membership : [SELECT MemberId FROM CollaborationGroupMember WHERE CollaborationGroupId = : this.myPool.Chatter_Group__c AND MemberId != : this.UserId])
                memberList.add(membership.MemberId);
            this.parseExcludeList();
            Set<String> excludeThese = this.excludeList.get(this.UserId);
            for (User u : [SELECT name FROM User WHERE id =: memberList AND id != : this.UserId AND Name !=: this.mypool.Moderator_Name__c ORDER BY name ASC]){
                SelectOption o = new SelectOption(u.id, u.name);
                this.allPicks.add(o);
                if (excludeThese != null && excludeThese.contains(u.id))
                    this.notOkPicks.add(o);
                else
                    this.okPicks.add(o);
                   
            }
            
            List<Gift_Exchange_Participant__c> parts = [SELECT id, Gift_Exchange_Pool__c, Got_Gift__c, Selection__c  FROM Gift_Exchange_Participant__c WHERE Participant__c = : this.userId AND Gift_Exchange_Pool__c =: this.myPool.id];
            if (parts.size() != 0){
                this.myParticipation = parts[0];
                List<User> picks = [SELECT name, SmallPhotoUrl, id FROM User WHERE id = : myParticipation.Selection__c];
                if (picks.size() == 1)
                    this.myPick = picks.get(0);
                else{
                    ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, 'Gift Exchange was unable to pick a name for you due to lack of participation. Try deleting the pool and starting again.'));
                    this.myPick =  [SELECT name, SmallPhotoUrl, id FROM User WHERE id = : this.userId];
                }
            }
            
            
        }
        
        // public / page functions - Pool Class
        
        // Returns true is user has signed up for a pool.
        public Boolean getIsSignedUp() {
            if (this.myPool != null || this.myParticipation != null)
                return true;
            return false;
        }
        
       // Shows admin panel if user runs a pool.
       public Boolean getShowAdminPanel() {
            if (this.getIsSignedUp() && this.myPool.OwnerId == this.userId)
               return true;
            return false;
        }
        
        // Moves user from "Do Not Pick" list to "Participants" list on "Do Not Pick" tab.
        public PageReference includePart() {
            for (integer x = 0; x < this.notOkPicks.size(); x++)
                if (this.notOkPicks.get(x).getValue() == excludeSelect)
                    this.notOkPicks.remove(x);
            for (integer x = 0; x < this.allPicks.size(); x++)
                if (this.allPicks.get(x).getValue() == excludeSelect)
                    this.okPicks.add(this.allPicks.get(x));
            this.saveExcludeList();
            return null;
        }
        
        // Moves user from "Participants" list to "Do Not Pick" list on "Do Not Pick" tab.
        public PageReference excludePart() {
            if (this.notOkPicks.size() == 3){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR, 'To be fair to everyone, Gift Exchange only allows you to add up to 3 people to the "Do Not Pick" list.'));
                return null;
            }
            for (integer x = 0; x < this.okPicks.size(); x++)
                if (this.okPicks.get(x).getValue() == partSelect)
                    this.okPicks.remove(x);
            for (integer x = 0; x < this.allPicks.size(); x++)
                if (this.allPicks.get(x).getValue() == partSelect)
                    this.notOkPicks.add(this.allPicks.get(x));
            this.saveExcludeList();
            return null;
        }
        
        // Returns formatted date string of pool's sign up deadline.
        public String getDeadline() {
            if (Schema.sObjectType.Gift_Exchange_Pool__c.fields.Sign_Up_Date__c.isAccessible()){
                return String.valueOf(this.myPool.Sign_Up_Date__c.format());
            }
            return '';
        }
        
        // Changes pool settings changes cron time for the 
        public PageReference changeSettings() {
            update this.myPool; 
            return null;
        }
        
        // Returns either a name or generic "your pick" name depending on if names
        // have been drawn.
        public String getPick() {
            if (this.myPick != null)
             return this.myPick.name;
            return 'your pick';
        }
        
        
        // Quick link to chatter posts of respones to anonymous questions.
        public String getResponseLink() {
            String s = getPick().replace(' ' , '+');
            return '/_ui/common/search/client/ui/ChatterSearchResultsPage?searchType=2&str=Hey+' + s + '%21';
        }
        
        // Get the userId of your pick.
        public String getPickUrl() {
             return this.myPick.id;
        }
        
        // Image url of your pick.
        public String getPickPic() {
             return this.myPick.SmallPhotoUrl;
        }
        
        // Change flag indicating indicating that you got your pick a gift.
        public PageReference setGiftGot() {
            this.myParticipation.Got_Gift__c = this.iGotGift;
            update this.myParticipation;
            return null;
        }
        
        // Set invitation message if user owns the group.
        public String getInviteMessage() {
            String s = 'Invite your coworkers to join the group on Chatter';
            if (this.myPool.OwnerId == this.userId)
               s += ' or add them to the group yourself';
            s += '.';
            return s;
        }
        
        // Send an anonymous question to a queue to be posted next 12:00 pm.
        public PageReference sendMess() {
            if (this.myPool.Messages__c == null) this.myPool.Messages__c = '';  
            this.myPool.Messages__c += '.\nHey ' + myPick.name + '! \n\n';
            this.myPool.Messages__c += 'Someone wants to know: \n\n';
            this.myPool.Messages__c += '"'+ this.myAnonMessage+'"#EOM';
            update this.myPool;
            this.myAnonMessage = '';
            
            String msg = 'Your message has been saved. It will be posted on the chatter group at noon ';
            if (system.now().hour() < 12)
                msg += 'today. ';
            else
                msg += 'tomorrow. ';
            
            ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, msg));
            
            return null;
        }
        
        // Private functions
        
        // Saves the "Do Not Pick" list from the UI to the ExcludeList__c field on the pool object.
        private void saveExcludeList(){
            Set<String> myList = new Set<String>();
            for (SelectOption notOk : this.notOkPicks){
                myList.add(notOk.getValue());
            }
            this.excludeList.put(this.UserId, myList);
            
            Boolean firstRow = true;
            String s = '';
            for (String key : this.excludeList.keySet()){
                if (firstRow)
                    firstRow = false;
                else
                    s += '~';
                myList = this.excludeList.get(key);
                if (myList.size() > 0){
                    s += key;
                    for (String col : myList)
                       s += ':' + col;           
                }
            }
            this.myPool.ExcludeList__c = s;
            update this.myPool;
        }
        
        
        // Parses the ExcludeList__c into list for "Do Not Pick" UI.
        private void parseExcludeList(){
            this.excludeList = new Map<String, Set<String>>();
            if (this.myPool != null && this.myPool.ExcludeList__c != null){
                List<String> rows = this.myPool.ExcludeList__c.split('~');
                for (String row : rows){
                    List<String> cols = row.split(':');
                    String key = cols.get(0);
                    cols.remove(0);
                    Set<String> myList = new Set<String>();
                    myList.addAll(cols);
                    this.excludeList.put(key, myList);
                }
            }
        }  
       
    } // End Pool Class
    
    
    // Public funtions
    
    // Shows full instructions for using app.
    public Boolean getNeedNewPool() {
        if (this.myPools.size() == 0 && this.setupStep == 0){
            return true;
        }
        return false;
    }
  
    // On Screen 1 of new pool setup.
    public Boolean getStep1Setup() {
        if (this.setupStep == 1)
            return true;
        return false;
    }
    
    // On Screen 2 of new pool setup.
    public Boolean getStep2Setup() {
        if (this.setupStep == 2)
            return true;
        return false;
    }

    
    //
    // private functions
    //
    
    // Intialize page from constructor.
    private void initPage(){
        this.setupStep = 0;
        
        this.userId = UserInfo.getUserId();
        
        // Gather chatter groups that user is a part of.
        List<String> chatterGroups = new List<String>(); 
        for (CollaborationGroupMember membership : [SELECT CollaborationGroupId FROM CollaborationGroupMember WHERE MemberId = : this.UserId])
            chatterGroups.add(membership.CollaborationGroupId);
            
        // Gather pools that User is a part of.
        Map<id,Gift_Exchange_Pool__c> pools = new Map<id,Gift_Exchange_Pool__c>([SELECT id, 
                                                                                        name, 
                                                                                        Chatter_Group__c, 
                                                                                        Sign_Up_Date__c, 
                                                                                        Gift_Giving_Time__c, 
                                                                                        Cron_Job_1__c, 
                                                                                        Names_Drawn__c, 
                                                                                        Messages__c, 
                                                                                        OwnerId, 
                                                                                        Organizer_Name__c ,
                                                                                        Moderator_Name__c,
                                                                                        ExcludeList__c
                                                                                   FROM Gift_Exchange_Pool__c
                                                                                   WHERE Chatter_Group__c = : chatterGroups]);
        
        
       
        
        myPools = new List<PoolClass>();
        
        // Create PoolClass wrappers and add to list.
        for (Gift_Exchange_Pool__c pool : pools.values()){
            PoolClass pc = new PoolClass(pool);
            myPools.add(pc);
        }
       
        
        List<Gift_Exchange_Participant__c> myParticipation = [SELECT id, Gift_Exchange_Pool__c, Got_Gift__c, Selection__c  FROM Gift_Exchange_Participant__c WHERE Participant__c = : this.userId];
        
        if (myParticipation.size() == 0) return;
        
        List<id> poolIds = new List<id>();
        for (Gift_Exchange_Participant__c p : myParticipation){
            poolIds.add(p.Gift_Exchange_Pool__c);
        }
        
        
    }

   
   
    //
    // page actions
    //
    
    // Create a new Pool.
    public PageReference createNewPool() {
        // FLS Check
        String [] userUpdateFields = new String [] {'alias','email', 'emailencodingkey', 'lastname', 
                                                        'languagelocalekey', 'localesidkey', 'profileid',
                                                        'timezonesidkey', 'username'};
        
       
        if (!Schema.sObjectType.Gift_Exchange_Pool__c.fields.Sign_Up_Date__c.isCreateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Chatter_Group__c.isCreateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Cron_Job_2__c.isCreateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Moderator__c.isCreateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Sign_Up_Date__c.isUpdateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Chatter_Group__c.isUpdateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Cron_Job_2__c.isUpdateable()||
            !Schema.sObjectType.Gift_Exchange_Pool__c.fields.Moderator__c.isUpdateable()){
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Insufficient access'));
                
            return null; 
        }
        
        // Obtaining the field name/token map for the User object 
        Map<String,Schema.SObjectField> m = Schema.SObjectType.User.fields.getMap(); 
        for (String fieldToCheck : userUpdateFields) {
            // Check if the user has create access on the each field 
            if (!m.get(fieldToCheck).getDescribe().isCreateable()) {
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Insufficient access'));
                return null; 
            }
        }
        
        // Create Chatter group for pool.
        CollaborationGroup chatterGroup = new CollaborationGroup(CollaborationType = 'Public');
        chatterGroup.name = this.dummyPool.name;
        this.dummyPool.Sign_Up_Date__c = this.dummyPool.Gift_Giving_Time__c.addDays(Integer.valueOf(this.deadlinePick) * (-7));
        
        insert chatterGroup;
        this.dummyPool.Chatter_Group__c = chatterGroup.id;
        
        
        // Create a cron job to pick out names.
        Date n = this.dummyPool.Sign_Up_Date__c;
        
        String cron = '';

        cron += '0';
        cron += ' 0';
        cron += ' 12';
        cron += ' ' + n.day();
        cron += ' ' + n.month();
        cron += ' ' + '?';
        cron += ' ' + n.year();
        
        
        string cronId = System.schedule(this.dummyPool.name + ' Daily Check ' + (Math.random()*999).intValue(), '0 0 12 * * ?', new GiftExchangeDailyReport());
        
        this.dummyPool.Cron_Job_2__c = cronId;
        
        insert this.dummyPool;
        
        
        // Create a 3rd party Chatter Free user to serve as the group's MC.
        Profile p = [SELECT id From profile WHERE name='Chatter Moderator User'];
        
        User u = new User(alias = 'giftMod', email='giftmod@testorg.com',
            emailencodingkey='UTF-8', lastname=this.dummyPool.Moderator_Name__c, languagelocalekey='en_US',
            localesidkey='en_US', profileid = p.Id,
            timezonesidkey='America/Los_Angeles', username='giftMod@'+this.dummyPool.id+'.com');
            
        insert u;
        
        this.dummyPool.Moderator__c = u.id;
        
        update this.dummyPool;
        
        // Add MC to group.
        insert new CollaborationGroupMember (CollaborationGroupId = chatterGroup.id, MemberId = u.id);
        
        
        // Send out intro message to group.
        List<SObject> inserts = new List<SObject>();
        
        FeedItem post = new FeedItem();
        post.parentId = chatterGroup.id;
        post.body = 'Hello everyone! I will be your organizer for ' + this.dummyPool.name + '. \n\n'; 
        post.body += 'To participate in this gift exchange, simply join this Chatter group by ' + this.dummyPool.Sign_Up_Date__c.format() + '. '; 
        post.body += 'At that time, we will be drawing names for our gift exchange on ' + this.dummyPool.Gift_Giving_Time__c.format() + '. \n\n';
        post.body += 'Invite your friends and let\'s have fun this year!';
        post.CreatedById = u.id;
        post.CreatedDate = System.now();
        
        inserts.add(post);
        
        Gift_Exchange_Participant__c participant = new Gift_Exchange_Participant__c();
        participant.Gift_Exchange_Pool__c = this.dummyPool.id;
        participant.Participant__c = this.userId;
    
        insert inserts;
        
        
        ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.CONFIRM, 'Your pool has been created. Invite your coworkers to the ' + chatterGroup.name + ' group on Chatter!'));
        
        this.setupStep++;
        
        PoolClass pc = new PoolClass(this.dummyPool);
        myPools.add(pc);
        return null; 
    }
    
    
    // Go back a page in the new pool setup.
    public PageReference prevPage() {
        this.setupStep--;
        return null;
    }
    
    // Delete all pools in the system. (Hard reset)
    public PageReference deletePool() {
        GiftExchangeCronJobs.clearAll();
        this.initPage();
        return null;
    }

    // Go forward a page in the new pool setup.
    public PageReference nextPage() {
        if (this.setupStep == 0){
            this.dummyPool = new Gift_Exchange_Pool__c ( );
            this.dummyPool.name = POOL_NAME + ' ' + Date.today().year();
            this.dummyPool.Moderator_Name__c = MOD_NAME;
            this.deadlinePick = '2';
        } else if (this.setupStep == 1){
            List<CollaborationGroup> g = [SELECT id FROM CollaborationGroup WHERE name =: this.dummyPool.name];
            if (g.size() != 0){
                ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.FATAL, 'Name is already in use. Please select new name.' ));
                return null;
            }
        }
        this.setupStep++;
        return null;
    }



}