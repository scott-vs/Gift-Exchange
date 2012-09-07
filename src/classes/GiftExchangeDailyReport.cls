// Scheduled class to fire off the daily cron job. 
global class GiftExchangeDailyReport implements Schedulable { 
    global void execute(SchedulableContext ctx) {
         GiftExchangeCronJobs.dailyCheck();
    }
}