/*
 * ****************************************************************************
 * Description : RecordTypeAuditor class gathers metadata on all RecordTyopes
 *               and displays the results in the RecordType_Audit_View VisualForce page
 * *****************************************************************************/


public class RecordTypeAuditor {

    public class RecordTypeData {
        public String id {get; set;}
        public String objectName {get; set;}
        public String label {get; set;}
        public String apiName {get; set;}
        public String description {get; set;}
        public Boolean isActive {get; set;}
        public String createdBy {get; set;}
        public String lastModifiedBy {get; set;}
        public Datetime createdDate {get; set;}
        public Datetime lastModifiedDate {get; set;}
    }
    
    public List<RecordTypeData> resultsList {get; set;}
    
    // User entered Object API name that they would like to audit
    public String selectedObject {get; set;}
    
    /**
     * Called when a user enters an object for which they'd like to see all RecordTypes
     **/
    public void auditObject(){
        String queryString = 'SELECT Id,SObjectType,Name,DeveloperName,Description,IsActive,CreatedBy.Name,LastModifiedBy.Name,CreatedDate,LastModifiedDate FROM RecordType where SObjectType = :selectedObject';   
		auditRecordTypes(queryString);
    }
    
    /**
     * Called when a user selects "Audit All Objects" button
     **/
    public void auditAll(){
        String queryString = 'SELECT Id,SObjectType,Name,DeveloperName,Description,IsActive,CreatedBy.Name,LastModifiedBy.Name,CreatedDate,LastModifiedDate FROM RecordType Order By SObjectType';
    	auditRecordTypes(queryString);
    }
    
    /**
     * Runs the appropriate query to gather RecordType data, 
     * generates RecordTypeData objects for each row returned,
     * and adds them to a results list to be displayed in a VF table on the frontend
     **/
    public void auditRecordTypes(String queryString){
        resultsList = new List<RecordTypeData>();
        List<RecordType> rt = new List<sObject>(Database.query(queryString));
       
        for(RecordType r : rt){
        	RecordTypeData rtData = new RecordTypeData();

            rtData.id = r.Id;
            rtData.objectName = r.SobjectType;
            rtData.label = r.Name;
            rtData.apiName = r.DeveloperName;
            rtData.description = r.Description;
            rtData.isActive = r.IsActive;
            rtData.createdBy = r.CreatedBy.Name;
            rtData.lastModifiedBy = r.LastModifiedBy.Name;
            rtData.createdDate = r.CreatedDate;
            rtData.lastModifiedDate = r.LastModifiedDate;
            
            resultsList.add(rtData);
        }
    }
}