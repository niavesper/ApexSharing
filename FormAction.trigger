trigger FormAction on Form__c(after insert, after update) {
  FormAction.passVariablesToMethods(Trigger.new, Trigger.oldMap);
}
