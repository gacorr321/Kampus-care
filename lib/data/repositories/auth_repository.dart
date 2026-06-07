import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cek user sedang login atau tidak
  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register
  Future<UserModel> register({
    required String name,
    required String email,
    required String nim,
    required String phone,
    required String password,
    String? ktmUrl,
  }) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final user = UserModel(
      uid: credential.user!.uid,
      name: name,
      email: email,
      nim: nim,
      phone: phone,
      ktmUrl: ktmUrl,
    );

    // Simpan data user ke Firestore
    await _firestore.collection('users').doc(user.uid).set(user.toMap());

    return user;
  }

  // Login
  Future<UserModel> login({
    required String name,
    required String nim,
    required String password,
  }) async {
    // 1. Cari user berdasarkan NIM di Firestore
    final query = await _firestore
        .collection('users')
        .where('nim', isEqualTo: nim)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw Exception('NIM tidak terdaftar');
    }

    final userData = query.docs.first.data();
    
    // 2. Cocokkan nama lengkap (case-insensitive)
    final registeredName = userData['name'] as String;
    if (registeredName.trim().toLowerCase() != name.trim().toLowerCase()) {
      throw Exception('Nama Lengkap atau NIM tidak sesuai');
    }

    final email = userData['email'] as String;

    // 3. Sign in dengan email dan password
    await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    return UserModel.fromMap(userData);
  }

  // Update Profile
  Future<UserModel> updateProfile({
    required String uid,
    required String name,
    required String nim,
    required String phone,
    String? email,
  }) async {
    final updateData = {
      'name': name,
      'nim': nim,
      'phone': phone,
    };
    
    await _firestore.collection('users').doc(uid).update(updateData);
    
    // Update reported items
    final itemsQuery = await _firestore.collection('items').where('reportedBy', isEqualTo: uid).get();
    if (itemsQuery.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in itemsQuery.docs) {
        batch.update(doc.reference, {
          'reportedByName': name,
          'reportedByPhone': phone,
        });
      }
      await batch.commit();
    }

    // Update claimed items
    final claimedQuery = await _firestore.collection('items').where('claimedBy', isEqualTo: uid).get();
    if (claimedQuery.docs.isNotEmpty) {
      final batch = _firestore.batch();
      for (var doc in claimedQuery.docs) {
        batch.update(doc.reference, {
          'claimerName': name,
        });
      }
      await batch.commit();
    }
    
    // Fetch updated user data
    final doc = await _firestore.collection('users').doc(uid).get();
    return UserModel.fromMap(doc.data()!);
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }
}
