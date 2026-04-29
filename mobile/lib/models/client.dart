/// Клиент (из JWT после логина)
class Client {
  final String clientId;
  final String fullName;
  final String phone;
  final String tenantName;  // название МФО
  final String token;

  const Client({
    required this.clientId,
    required this.fullName,
    required this.phone,
    required this.tenantName,
    required this.token,
  });

  factory Client.fromLoginResponse(Map<String, dynamic> json, String token) => Client(
        clientId:   json['client']['clientId'],
        fullName:   json['client']['fullName'] ?? '',
        phone:      json['client']['phone']    ?? '',
        tenantName: json['client']['tenantName'] ?? '',
        token:      token,
      );
}
