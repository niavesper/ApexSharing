// Date:    ####
// Author:  ####
// Description:   Class created to insert and delete Form__Share records depending on the values of
// (1) the lookups Supervisor_Manager__c and Division_Director__c and
// (2) the values of records of CMDT Department_Management__mdt.
// See Case 05-2023-31143 ("PAR issues") for more context.
// History:   V.1
public without sharing class FormAction {

  // Define the custom exception as an inner class. To be used if a DML operation fails
  public class CustomException extends Exception {}

  public static void passVariablesToMethods(List<Form__c> forms, Map<Id, Form__c> oldFormsMap) {
    // Initialize sets to store user IDs for sharing and deletion    
    Set<Id> userIdsForSharing = new Set<Id>();
    Set<Id> userIdsForDeletion = new Set<Id>();

    // Populate user IDs based on Form lookups (Supervisor_Manager__c and Division_Director__c)
    // for the purposes of creating share records
    passSupervisorAndDirectorToHelperCreate(forms, userIdsForSharing);

    // Populate user IDs based on Department_Management__mdt
    passCMDTManagersToHelper(userIdsForSharing);

    // Create and insert share records for the specified user IDs
    createAndInsertShares(forms, userIdsForSharing);

    // Populate user IDs based on Form lookups (Supervisor_Manager__c and Division_Director__c)
    // for the purposes of deleting share records
    if (oldFormsMap != null) {    
    passSupervisorAndDirectorToHelperDelete(forms, userIdsForDeletion, oldFormsMap);
    }
    // Delete share records for the specified user IDs
    deleteShareRecords(userIdsForDeletion);
  }
 
  /* Helper method for checking if user IDs in lookups (Supervisor_Manager__c and Division_Director__c)
   are null and if not, adding them to the userIdsForSharing set.
   The parameters are passed to this method by the method passSupervisorAndDirectorToHelperCreate */
  private static void addUserIdsToSetForShareCreation(Id lookup, Set<Id> userIdsForSharing) {
    if (lookup != null) {
      userIdsForSharing.add(lookup);
    }
  }

  /* Method for passing (1) user IDs (Supervisor_Manager__c and Division_Director__c) and
  (2) a set of IDs (userIdsForSharing) to the helper method which adds those IDs to the set.
  The parameters are passed to this method by the method passVariablesToMethods*/
  private static void passSupervisorAndDirectorToHelperCreate(List<Form__c> forms, Set<Id> userIdsForSharing) {
    for (Form__c f : forms) {
      if (f.Supervisor_Manager__c != null) {
        addUserIdsToSetForShareCreation(f.Supervisor_Manager__c, userIdsForSharing);
      }
      if (f.Division_Director__c != null) {
        addUserIdsToSetForShareCreation(f.Division_Director__c, userIdsForSharing);
      }
    }
  }

  /* Method for (1) finding users whose email addresses match email addresses from CMTD records that store 
  the Executive Director and Finance Director info and (2) adding IDs of those upper manager users to the 
  userIdsForSharing set.*/
  private static void passCMDTManagersToHelper(Set<Id> userIdsForSharing) {
    // A set to hold email addresses of dept manager users with whom the Form__c records will be shared
    Set<String> departmentManagerEmails = new Set<String>();

    // Query CMDT records that contain Executive Director and Finance Director info and add them to a list
    List<Department_Management__mdt> deptMgmtRecords = [
      SELECT Email_Address__c
      FROM Department_Management__mdt
      WHERE DeveloperName IN ('Executive_Director', 'Finance_Director')
    ];

    if (!deptMgmtRecords.isEmpty()) {
      // Loop through queried CMDT records and add their emails to the set instantiated earlier
      for (Department_Management__mdt dM : deptMgmtRecords) {
        if (dM.Email_Address__c != null) {
          departmentManagerEmails.add(dM.Email_Address__c);
        }
      }

      // Query user records whose emails match those from CMDT and add them to a list
      List<User> managerUsers = [
        SELECT Id
        FROM User
        WHERE Email IN :departmentManagerEmails
      ];

      //Loop through users in the list and add their IDs to the userIdsForSharing set
      if (!managerUsers.isEmpty()) {
        for (User u : managerUsers) {
          userIdsForSharing.add(u.Id);
        }
      }
    }
  }

  /* Method for creating and inserting share records for each user in the set*/
  public static void createAndInsertShares(List<Form__c> forms, Set<Id> userIdsForSharing) {
    // A list to hold share records to be inserted
    List<Form__Share> sharesToInsert = new List<Form__Share>();
    // Create Form__Share records for each Form__c record and User ID combination.
    for (Form__c f : forms) {
      for (Id uId : userIdsForSharing) {
        Form__Share share = new Form__Share();
        share.ParentId = f.Id;
        share.UserOrGroupId = uId;
        share.AccessLevel = 'Read';
        share.RowCause = 'ApexSharingManagers__c'; // This is an Apex Sharing Reason (currently can be seen and configured only in Classic)
        sharesToInsert.add(share);
      }
    }

    // Insert all of the newly created Share records and capture save result
    Database.SaveResult[] formShareInsertResult = Database.insert(sharesToInsert,true);

    // Check the results of the insert operation and handle any errors
    for (Database.SaveResult result : formShareInsertResult) {
      if (!result.isSuccess()) {

        // THIS LINE IS NOT COVERED
        for (Database.Error error : result.getErrors()) {
          System.debug(
            'Error while inserting Form__Share record: ' + error.getMessage()
          );

          // THIS LINE IS NOT COVERED
          throw new CustomException('Error while inserting Form__Share record: ' + error.getMessage());
        }
      }
    }
  }

  /* Helper method for checking if Supervisor_Manager__c or Division_Director__c lookup fields have been updated
  on an existing Form__c object and if yes, adding old lookup values (IDs) to the set userIdsForDeletion.
  The parameters are passed to this method by the method passSupervisorAndDirectorToHelperDelete.*/
  private static void addUserIdsToSetForShareDeletion(Id lookup, Id oldLookup, set<Id> userIdsForDeletion) {
    if (lookup != oldLookup) {
      userIdsForDeletion.add(oldLookup);
    }
  }

  /*Method for passing user IDs (old and new IDs from the Supervisor_Manager__c and Division_Director__c fields)
  and a set (userIdsForDeletion) to the helper method, which adds old IDs to the set userIdsForDeletion. */
  public static void passSupervisorAndDirectorToHelperDelete(List<Form__c> forms, Set<Id> userIdsForDeletion, Map<Id, Form__c> oldFormsMap) {
    for (Form__c f : forms) { 
      Form__c oldF = oldFormsMap.get(f.Id);
      // We are not checking if Supervisor_Manager__c or Division_Director__c are null. It's ok for them to be null because we also
      // want to delete old share records for users who used to be in these fields if these fields go from populated to null
      if (oldF != null) {
        addUserIdsToSetForShareDeletion(
          f.Supervisor_Manager__c,
          oldF.Supervisor_Manager__c,
          userIdsForDeletion
        );

        addUserIdsToSetForShareDeletion(
          f.Division_Director__c,
          oldF.Division_Director__c,
          userIdsForDeletion
        );    
      }
    }
  }

    /* Method for (1) querying share records that share the Form__c record with users from the userIdsForDeletion set
     i.e., users who used to be in the Supervisor_Manager__c and Division_Director__c lookup fields
    before those fields got updated; (2) assigning those share records to a list and (3) deleting them.
    The parameters are passed to this method by the method passVariablesToMethods*/
    public static void deleteShareRecords(Set<Id> userIdsForDeletion){
    if (!userIdsForDeletion.isEmpty()) {
      List<Form__Share> sharesToDelete = [
        SELECT Id, UserOrGroupId
        FROM Form__Share
        WHERE
          UserOrGroupId IN :userIdsForDeletion
          // You will get an error when triggering deletion if you don't specify RowCause here
          AND RowCause = 'ApexSharingManagers__c'
      ];

      // Delete Share records that are in the list sharesToDelete
      if (!sharesToDelete.isEmpty()) {
        List<Database.DeleteResult> deleteResults = Database.delete(sharesToDelete);

        // Check the results of the delete operation.

        // THIS LINE IS NOT COVERED
        for (Database.DeleteResult result : deleteResults) {
          if (!result.isSuccess()) {
            for (Database.Error error : result.getErrors()) {
              System.debug(
                'Error while deleting Form__Share record: ' + error.getMessage()
              );

              // THIS LINE IS NOT COVERED
              throw new CustomException('Error while inserting Form__Share record: ' + error.getMessage());
            }
          }
        }
      }
    }
  }
}
