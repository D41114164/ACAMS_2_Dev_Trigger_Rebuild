trigger ACAMSAccountTrigger on Account (before insert, before update) {
    (new ACAMSAccountTriggerHandler()).run();
}