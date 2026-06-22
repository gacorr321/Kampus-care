import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/complaint_model.dart';

class ComplaintRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  
  Future<void> submitComplaint(ComplaintModel complaint) async {
    await _firestore
        .collection('complaints')
        .doc(complaint.id)
        .set(complaint.toMap());
  }


  Stream<List<ComplaintModel>> getComplaintsByReport(String reportId) {
    return _firestore
        .collection('complaints')
        .where('reportId', isEqualTo: reportId)
        .orderBy('submittedAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => ComplaintModel.fromMap(d.data())).toList());
  }
}
