trigger ACAMSUserTrigger on User (after insert) {
    new ACAMSUserTriggerHandler().run();
}