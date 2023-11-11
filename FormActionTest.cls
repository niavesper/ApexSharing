// Description:   Class created to test FormAction class.

@isTest
private class FormActionTest {
  // Helper method to create User records
  private static List<User> createUserRecords(
    Integer numUsers,
    String role,
    id profileId
  ) {
    List<User> users = new List<User>();
    for (Integer i = 1; i <= numUsers; i++) {
      users.add(
        new User(
          LastName = role + ' Test User ' + i,
          Email = role + i + '@example.com',
          Username = role + i + '@example.com',
          Alias = 'alias' + i,
          TimeZoneSidKey = 'GMT',
          LocaleSidKey = 'en_US',
          EmailEncodingKey = 'UTF-8',
          ProfileId = profileId,
          LanguageLocaleKey = 'en_US',
          Division = 'Administration'
        )
      );
    }
    insert users;
    return users;
  }

  // Helper method to create Form__c records with unique Supervisor and Director
  private static List<Form__c> createFormRecords(
    Integer numForms,
    List<Id> supervisorIds,
    List<Id> directorIds,
    String ein
  ) {
    List<Form__c> forms = new List<Form__c>();
    for (Integer i = 0; i < numForms; i++) {
      Form__c newForm = new Form__c(EIN__c = ein);

      // Check if supervisorIds is not null and has enough elements
      if (supervisorIds != null && i < supervisorIds.size()) {
        newForm.Supervisor_Manager__c = supervisorIds[i];
      }

      // Check if directorIds is not null and has enough elements
      if (directorIds != null && i < directorIds.size()) {
        newForm.Division_Director__c = directorIds[i];
      }

      forms.add(newForm);
    }
    insert forms;
    return forms;
  }

  // Method for returning users whose emails addresses match those from relevant CMDT records
  // To be used in asserting expected number of created shares
  static Set<Id> getCMDTusers() {
    // A set to hold the emails from relevant CMDT records
    Set<String> cmdtEmails = new Set<String>();

    // Query CMDT records that contain Executive Director and Finance Director info and add them to a list
    List<Department_Management__mdt> deptMgmtRecords = [
      SELECT Email_Address__c
      FROM Department_Management__mdt
      WHERE
        DeveloperName = 'Executive_Director'
        OR DeveloperName = 'Finance_Director'
    ];

    if (!deptMgmtRecords.isEmpty()) {
      // Loop through queried CMDT records and add their emails to the set instantiated earlier
      for (Department_Management__mdt dM : deptMgmtRecords) {
        if (dM.Email_Address__c != null) {
          cmdtEmails.add(dM.Email_Address__c);
        }
      }
    }

    // Query user records whose emails match those from CMDT
    List<User> cmdtUsers = [
      SELECT Id
      FROM User
      WHERE Email IN :cmdtEmails
    ];

    // Convert list to set since we need to return a set
    // (having a set prevents the possibility of duplicate values)
    Set<Id> cmdtUserIds = new Set<Id>();
    for (User u : cmdtUsers) {
      cmdtUserIds.add(u.Id);
    }

    return cmdtUserIds;
  }

  @testSetup
  static void setupTestData() {
    // Declare variables to be used inside of the try-catch block. This is necessary because
    // variables declared inside of the try block are not accessible outside of it.
    List<Profile> profiles;
    Profile p;
    List<User> supervisorUsers;
    List<User> directorUsers;

    try {
      // Start of the try block where we place code that might throw an exception
      // Query to fetch a profile by its Name. The query result will be stored in the 'profiles' list.
      profiles = [
        SELECT Id
        FROM Profile
        WHERE Name = '(DHA) Chatter Only User'
      ];
      // Check if the 'profiles' list is empty, meaning the profile was not found
      if (profiles.isEmpty()) {
        // Log a debug message if the profile is not found
        System.debug('Profile not found. Please ensure the profile exists.');
      } else {
        // If the profile is found, take the first one and assign it to variable 'p'
        p = profiles[0];
      }
    } catch (Exception e) {
      // Start of the catch block where we catch any exceptions thrown in the try block
      // Log the exception message if any error occurs
      System.debug('An error occurred: ' + e.getMessage());
    }

    if (p != null) {
      supervisorUsers = createUserRecords(20, 'Supervisor', p.Id);
      directorUsers = createUserRecords(20, 'Director', p.Id);
    }

    // Create Supervisor and Director test users for deletion testing
    List<User> supervisorUsersDeletion = createUserRecords(
      10,
      'SupervisorDelete',
      p.Id
    );
    List<User> directorUsersDeletion = createUserRecords(
      10,
      'DirectorDelete',
      p.Id
    );

    // Prepare lists of IDs for Supervisors and Directors
    List<Id> first10SupervisorIds = new List<Id>();
    List<Id> next10SupervisorIds = new List<Id>();
    List<Id> first10DirectorIds = new List<Id>();
    List<Id> next10DirectorIds = new List<Id>();

    // This loop helps ensure that different lists of supervisors and directors are passed
    // to the helper method
    for (Integer i = 0; i < 20; i++) {
      if (i < 10) {
        first10SupervisorIds.add(supervisorUsers[i].Id);
        first10DirectorIds.add(directorUsers[i].Id);
      } else {
        next10SupervisorIds.add(supervisorUsers[i].Id);
        next10DirectorIds.add(directorUsers[i].Id);
      }
    }

    // Create different sets of Form__c records with unique supervisors and directors.
    // Here, Form records are being created that have either actual or null values in the
    // Supervisor_Manager__c and Division_Director__c fields in order to test different scenarios
    createFormRecords(
      10,
      first10SupervisorIds,
      first10DirectorIds,
      'allManagerForms'
    );
    createFormRecords(10, next10SupervisorIds, null, 'supervisorOnlyForms');
    createFormRecords(10, null, next10DirectorIds, 'directorsOnlyForms');
    createFormRecords(10, null, null, 'noManagersForms');
  }

  // Method for assertions
  static void assertShareRecords(
    Integer expectedCount,
    List<Form__Share> actualShares
  ) {
    System.assertEquals(
      expectedCount,
      actualShares.size(),
      'Incorrect number of shares inserted.'
    );
  }

  // TEST METHOD #1. Tests insertion of shares for Form records where BOTH the Supervisor_Manager__c and the Division_Director__c
  // lookups are populated
  @isTest
  static void testAllManagerShareRecordsInsert() {
    // Query Forms to be inserted in the test
    List<Form__c> allManagerForms = [
      SELECT Id, Supervisor_Manager__c, Division_Director__c
      FROM Form__c
      WHERE EIN__c = 'allManagerForms'
    ];

    // Set to hold user IDs, to be used when inserting shares
    Set<Id> userIdsForSharing = new Set<Id>();

    // Query users in the Supervisor_Manager__c and Division_Director__c lookups on Forms, to be insterted in the test.
    // Convert lists to sets since userIdsForSharing needs to be a set to avoid accidental duplicate values
    // (because we don't want to create shares for the same user more than once).
    List<User> supervisorUsers = [
      SELECT Id
      FROM User
      WHERE
        Id IN (
          SELECT Supervisor_Manager__c
          FROM Form__c
          WHERE Id IN :allManagerForms
        )
    ];
    Set<Id> supervisorUserIds = new Set<Id>();
    for (User u : supervisorUsers) {
      supervisorUserIds.add(u.Id);
    }

    List<User> directorUsers = [
      SELECT Id
      FROM User
      WHERE
        Id IN (
          SELECT Division_Director__c
          FROM Form__c
          WHERE Id IN :allManagerForms
        )
    ];
    Set<Id> directorUserIds = new Set<Id>();
    for (User u : directorUsers) {
      directorUserIds.add(u.Id);
    }

    // Query users whose emails match emails from relevant CMDT records
    Set<Id> cmdtUserIds = getCMDTusers();

    // Add IDs of all users for whom share records will be created to the set instantiated earlier
    userIdsForSharing.addAll(supervisorUserIds);
    userIdsForSharing.addAll(directorUserIds);
    userIdsForSharing.addAll(cmdtUserIds);

    // Calculate total # of expected shares
    Integer expectedShareNum =
      allManagerForms.size() * userIdsForSharing.size();

    Test.startTest();
    FormAction.createAndInsertShares(allManagerForms, userIdsForSharing);
    Test.stopTest();

    // Query inserted shares. This includes Supervisor/Managers, Division Directors, and managers from CMDT
    List<Form__Share> insertedShares = [
      SELECT Id
      FROM Form__Share
      WHERE
        ParentId IN :allManagerForms
        AND RowCause = 'ApexSharingManagers__c'
        AND AccessLevel = 'Read'
    ];

    // Assert
    assertShareRecords(expectedShareNum, insertedShares);
  }

  // TEST METHOD #2. Tests insertion of shares for Form records where ONLY the Supervisor_Manager__c lookup is populated,
  // but the Division_Director__c lookup is null
  @isTest
  static void testSupervisorOnlyShareRecordsInsert() {
    // Query Forms to be inserted in the test
    List<Form__c> supervisorOnlyForms = [
      SELECT Id, Supervisor_Manager__c, Division_Director__c
      FROM Form__c
      WHERE EIN__c = 'supervisorOnlyForms'
    ];

    // Set to hold user IDs, to be used when inserting shares
    Set<Id> userIdsForSharing = new Set<Id>();

    // Query users in the Supervisor_Manager__c lookup on Forms, to be insterted in the test.
    // Convert list to set since userIdsForSharing needs to be a set to avoid accidental duplicate values
    // (because we don't want to create shares for the same user more than once).
    List<User> supervisorUsers = [
      SELECT Id
      FROM User
      WHERE
        Id IN (
          SELECT Supervisor_Manager__c
          FROM Form__c
          WHERE Id IN :supervisorOnlyForms
        )
    ];
    Set<Id> supervisorUserIds = new Set<Id>();
    for (User u : supervisorUsers) {
      supervisorUserIds.add(u.Id);
    }

    // Query users whose emails match emails from relevant CMDT records
    Set<Id> cmdtUserIds = getCMDTusers();

    // Add IDs of all users for whom share records will be created to the set instantiated earlier
    userIdsForSharing.addAll(supervisorUserIds);
    userIdsForSharing.addAll(cmdtUserIds);

    // Calculate total # of expected shares
    Integer expectedShareNum =
      supervisorOnlyForms.size() * userIdsForSharing.size();

    Test.startTest();
    FormAction.createAndInsertShares(supervisorOnlyForms, userIdsForSharing);
    Test.stopTest();

    // Query inserted shares. This includes Supervisor/Managers and managers from CMDT
    List<Form__Share> insertedShares = [
      SELECT Id
      FROM Form__Share
      WHERE
        ParentId IN :supervisorOnlyForms
        AND RowCause = 'ApexSharingManagers__c'
        AND AccessLevel = 'Read'
    ];

    // Assert
    assertShareRecords(expectedShareNum, insertedShares);
  }

  // TEST METHOD #3. Tests insertion of shares for Form records where ONLY the Division_Director__c lookup is populated,
  // but the Supervisor_Manager__c lookup is null
  @isTest
  static void testDirectorOnlyShareRecordsInsert() {
    // Query Forms to be inserted in the test
    List<Form__c> directorOnlyForms = [
      SELECT Id, Supervisor_Manager__c, Division_Director__c
      FROM Form__c
      WHERE EIN__c = 'directorsOnlyForms'
    ];

    Set<Id> userIdsForSharing = new Set<Id>();

    // Query users in the Division_Director__c lookup on Forms, to be insterted in the test.
    // Convert list to set since userIdsForSharing needs to be a set to avoid accidental duplicate values
    // (because we don't want to create shares for the same user more than once).
    List<User> directorUsers = [
      SELECT Id
      FROM User
      WHERE
        Id IN (
          SELECT Division_Director__c
          FROM Form__c
          WHERE Id IN :directorOnlyForms
        )
    ];
    Set<Id> directorUserIds = new Set<Id>();
    for (User u : directorUsers) {
      directorUserIds.add(u.Id);
    }

    // Query users whose emails match emails from relevant CMDT records
    Set<Id> cmdtUserIds = getCMDTusers();

    // Add IDs of all users for whom share records will be created to the set instantiated earlier
    userIdsForSharing.addAll(directorUserIds);
    userIdsForSharing.addAll(cmdtUserIds);

    // Calculate total # of expected shares
    Integer expectedShareNum =
      directorOnlyForms.size() * userIdsForSharing.size();

    Test.startTest();
    FormAction.createAndInsertShares(directorOnlyForms, userIdsForSharing);
    Test.stopTest();

    // Query inserted shares. This includes Division Directors and managers from CMDT
    List<Form__Share> insertedShares = [
      SELECT Id
      FROM Form__Share
      WHERE
        ParentId IN :directorOnlyForms
        AND RowCause = 'ApexSharingManagers__c'
        AND AccessLevel = 'Read'
    ];

    // Assert
    assertShareRecords(expectedShareNum, insertedShares);
  }

  // TEST METHOD #4. Tests insertion of shares for Form records where NEITHER the Supervisor_Manager__c nor the Division_Director__c
  // lookups are populated
  @isTest
  static void testNoManagerShareRecordsInsert() {
    // Query Forms to be inserted in the test
    List<Form__c> noManagerForms = [
      SELECT Id, Supervisor_Manager__c, Division_Director__c
      FROM Form__c
      WHERE EIN__c = 'noManagersForms'
    ];

    // Set to hold user IDs, to be used when inserting shares
    Set<Id> userIdsForSharing = new Set<Id>();

    // Query users whose emails match emails from relevant CMDT records
    Set<Id> cmdtUserIds = getCMDTusers();

    // Add IDs of all users for whom share records will be created to the set instantiated earlier
    userIdsForSharing.addAll(cmdtUserIds);

    // Calculate total # of expected shares
    Integer expectedShareNum = noManagerForms.size() * cmdtUserIds.size();

    Test.startTest();
    FormAction.createAndInsertShares(noManagerForms, userIdsForSharing);
    Test.stopTest();

    // Query inserted shares. This includes managers from CMDT
    List<Form__Share> insertedShares = [
      SELECT Id
      FROM Form__Share
      WHERE
        ParentId IN :noManagerForms
        AND RowCause = 'ApexSharingManagers__c'
        AND AccessLevel = 'Read'
    ];

    // Assert
    assertShareRecords(expectedShareNum, insertedShares);
  }

  // TEST METHOD #5. Tests deletion of shares for Form records where BOTH the Supervisor_Manager__c and the Division_Director__c
  // lookups are populated. We can extrapolate that if this works, share records for Forms with other lookup population
  // scenarios will work too
  @isTest
  static void testDeleteShareRecords() {
    // Query Forms to be passed to the deleteShareRecords method
    List<Form__c> allManagerForms = [
      SELECT Id, Supervisor_Manager__c, Division_Director__c
      FROM Form__c
      WHERE EIN__c = 'allManagerForms'
    ];

    // Instatiate maps to hold current and old Form records
    Map<Id, Form__c> allManagerFormsMap = new Map<Id, Form__c>();
    Map<Id, Form__c> oldManagerFormsMap = new Map<Id, Form__c>();

    if (!allManagerForms.isEmpty()) {
      // Convert the list to a map to represent the current state of Forms (these forms will be updated later)
      allManagerFormsMap = new Map<Id, Form__c>(allManagerForms);

      // Deep clone the map to represent the old state of Forms (before the update, which will be run later)
      oldManagerFormsMap = allManagerFormsMap.deepClone();
    }

    // Set to hold user IDs, to be used when deleting shares
    Set<Id> userIdsForDeletion = new Set<Id>();
    for (Id userId : oldManagerFormsMap.keySet()) {
      userIdsForDeletion.add(userId);
    }

    // Query users created for the purposes of updating lookups on forms stored in allManagerFormsMap
    List<User> newSupervisors = [
      SELECT Id
      FROM User
      WHERE LastName LIKE '%SupervisorDelete%'
    ];

    List<User> newDirectors = [
      SELECT Id
      FROM User
      WHERE LastName LIKE '%DirectorDelete%'
    ];

    // Update lookups on forms stored in allManagerFormsMap
    for (Integer i = 0; i < allManagerForms.size(); i++) {
      allManagerForms[i].Supervisor_Manager__c = newSupervisors[i].Id;
      allManagerForms[i].Division_Director__c = newDirectors[i].Id;
    }

    // Perform the update DML operation
    update allManagerForms;

    Test.startTest();
    FormAction.passSupervisorAndDirectorToHelperDelete(
      allManagerForms,
      userIdsForDeletion,
      oldManagerFormsMap
    );
    Test.stopTest();

    // Query to check that no sharing records exist for these forms after deletion
    List<Form__Share> deletedShares = [
      SELECT ParentId, UserOrGroupId, AccessLevel, RowCause
      FROM Form__Share
      WHERE
        UserOrGroupId IN :oldManagerFormsMap.keySet()
        AND RowCause = 'ApexSharingManagers__c'
        AND AccessLevel = 'Read'
    ];

    // Check that no sharing records exist
    System.assertEquals(
      0,
      deletedShares.size(),
      'Sharing records were not deleted.'
    );
  }
}
