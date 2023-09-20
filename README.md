# Business scenario


Records of the Form__c object hold sensitive info about raises, salary rates, and promotions, so their sharing model is private. Only a limited number of people should be able to have access to these records. Forms are created when info about new hires, promotions, or one-time bonuses needs to be entered and sent for approvals. The records get created by direct managers of employees being hired or promoted, by upper managers (managers of direct managers), and by upper managers' assistants.


When a form is filled out, it gets sent for approvals through a standard approval process. The approvers are, in this order: 
Supervisor/Manager (user in the Supervisor/Manager lookup field on the Form)
Division Director (user in the Division Director lookup field on the Form)
Dept Executive Director (specified directly in the approval process)
Dept Finance Director (specified directly in the approval process).


Everyone listed below needs to have access to it, but no one else:
the creator
all the approvers
users above them in the role hierarchy


When the value of the lookups (to user) Supervisor/Manager and Division Director change, share records for old users (those that used to be in the lookups) need to be deleted.


# Additional considerations


- Supervisor/Manager will not always be above the Form creator in the role hierarchy -- the two could be in the same role (or the same person)
- There are multiple Supervisor/Managers within the same Division
- Finance Director and Executive Director will always be the same people (on every form), but Supervisor/Managers and Division Directors will be different on different forms.
- Division Director will not always be above Supervisor/Manager in the role hierarchy -- the two could be in the same role
- Division Director will not always be above the form creator in the role hierarchy -- the two could be in the same role
- Finance Director and Executive Director will always be above everyone else in the role hierarchy. They are in the same role
-  “Grant Access Using Hierarchies” is checked in Form’s sharing settings


# Why I gave up on deduplicating share records being created, even though the same person, e.g., Division Director, could end up with multiple share records for the same Form
I went down this amazing rabbit hole with GPT4 while trying to weed out the share record duplicates, and determined it's not possible -- or if it is, more complicated than it's worth. Below is the crux of the issue.

Two share records get created for the same person  -- let's say it's Division Director (DD), who is above Supervisor/Manager (SM) in the role hierarchy: one by my code and one by Salesforce due to the role hierarchy.  

So I click into a Form record > Sharing button > Edit next to "Shared with 5 groups of users” > "View Sharing Hierarchy” > View next to DD’s name. This is where I see SHARE RECORD 1 and SHARE RECORD 2 (see details below). 

Both of these records show up when you click View next to DD’s name:

SHARE RECORD 1
Shared With: User: DD
Reason for Access: “Apex Sharing: Managers” (this is the custom sharing reason I created and is same thing as share.RowCause = 'ApexSharingManagers__c')
Relationship: Self
Form Access: Read Only

SHARE RECORD 2
Shared With: User: SM
Reason for Access: “Apex Sharing: Managers”
Relationship: Manager of User
Form Access: Read Only

This tells me that DD was given access to the record twice: once as herself, due to my Apex class and the share record it creates, and the second time by Salesforce via the role hierarchy. So there must be some field that has something in common between SHARE RECORD 1 and SHARE RECORD 2 because they are both sharing the record with DD. And Salesforce knows to put them on the same page, next to DD’s name. So what I was hoping for is that my code would identify that DD would be given access to the record by Salesforce, because she is SM’s manager, and that my code would do deduplication and NOT create a share record (SHARE RECORD 1) for her.

ChatGPT suggested that I do the dupe check using a combo of ParentId (ID of the Form) and UserOrGroupId (Id of the User). BUT it doesn't work here because Shared With (aka UserOrGroupId) is not the same for these two records. There's gotta be something that is common between the two, because Salesforce knows to show them both when you go to View next to DD’s  name in Sharing Hierarchy, but I don't think it's any of the easily accessible fields of the Share object. Maybe there's a hidden related object or something. So when GPT and I came to this conclusion ("Salesforce doesn't provide a direct field that you can use to determine that two sharing records are essentially providing the same access to the same user due to role hierarchy"), it suggested querying roles, instead of the Share records ("If you need to make sure that DD isn't given a share directly by your code because she's already getting it via her position in the role hierarchy, you may have to write additional logic to traverse the role hierarchy yourself and identify such cases before creating your share records”).

I had already gone down that route once, and it was terribly complex (for me, anyway -- lots of nested logic and maps and other things) and I couldn't make it work. It was too difficult for me to troubleshoot because I couldn't fully understand what all it was doing in the first place. So at this point, I feel good about reverting to the version of code that doesn't account for duplicate creation. I feel like I gave it a really good try, what with the attempts to dedupe by role, then by ParentId + UserOrGroupId. It's possible someone more experienced would be able to accomplish it, but I don't know if the issue (having multiple share records for the same person who I already know SHOULD have access) is that big of a problem.
