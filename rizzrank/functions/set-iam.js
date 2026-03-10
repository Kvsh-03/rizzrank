const admin = require('firebase-admin');

async function setIAM() {
  try {
    await admin.initializeApp();
    
    // Set IAM for forfeitMatch
    await admin.functions().iam().setIamPolicy(
      admin.functions().httpsCallable('forfeitMatch').region('us-central1').path,
      {
        bindings: [
          {
            role: 'roles/cloudfunctions.invoker',
            members: ['allUsers']
          }
        ]
      }
    );
    
    console.log('IAM set successfully');
  } catch (error) {
    console.error('Error:', error.message);
  }
}

setIAM();
