class_name SgLanInvite
extends RefCounted
## [QoL] Temporary LAN invitations pin a host certificate, not a global identity.
## No persisted secrets, DNS lookup, public IPs, private keys or object decoding.

const PREFIX := "sglan1:"
const MAX_LENGTH := 8192
const COMMON_NAME := "sgmanalink.invalid"


static func address(value: Variant) -> bool:
	if not value is String or not value.is_valid_ip_address() or value.contains(":"):
		return false
	var parts: PackedStringArray = value.split(".")
	if parts.size() != 4:
		return false
	for part in parts:
		if str(int(part)) != part:
			return false
	var first := int(parts[0])
	var second := int(parts[1])
	return first == 10 or (first == 172 and second >= 16 and second <= 31) \
		or (first == 192 and second == 168) or (first == 169 and second == 254) \
		or value == "127.0.0.1"


static func local_addresses() -> PackedStringArray:
	var result := PackedStringArray()
	if OS.has_feature("web"):
		return result
	for item in IP.get_local_addresses():
		if address(item) and item != "127.0.0.1" and not result.has(item):
			result.append(item)
	result.sort()
	return result


static func public_pem(certificate: X509Certificate) -> String:
	if certificate == null:
		return ""
	# Godot 4.7.2 save_to_string() includes a NUL, reports a Unicode error and
	# appends U+FFFD. Reproduced: file bytes=1147, string length=1148, last=65533.
	# Export ONLY the public certificate through an automatically removed temp
	# file; the private key and all invitation/session secrets stay in memory.
	var temporary := FileAccess.create_temp(FileAccess.READ_WRITE, "sgmanalink-cert", "crt")
	if temporary == null or certificate.save(temporary.get_path()) != OK:
		return ""
	temporary.seek(0)
	var bytes := temporary.get_buffer(temporary.get_length())
	if bytes.is_empty() or bytes.size() > 4096 or bytes.has(0):
		return ""
	return bytes.get_string_from_ascii().replace("\r\n", "\n")


static func create(host: String, port: int, code: String, pem: String) -> String:
	if not address(host) or not SgProtocol.integer(port, 1, 65535) \
		or not SgProtocol.token(code) or pem.is_empty():
		return ""
	return PREFIX + Marshalls.raw_to_base64(JSON.stringify({"v": SgProtocol.VERSION,
		"address": host, "port": port, "access": code, "certificate": pem}).to_utf8_buffer())


static func parse(invitation: String) -> Dictionary:
	var data := _decode(invitation)
	if not SgProtocol.exact(data, ["v", "address", "port", "access", "certificate"]) \
		or not SgProtocol.integer(data.get("v"), SgProtocol.VERSION, SgProtocol.VERSION) \
		or not address(data.get("address")) or not SgProtocol.integer(data.get("port"), 1, 65535) \
		or not SgProtocol.token(data.get("access")) or not data.get("certificate") is String:
		return {}
	var pem := String(data.certificate)
	# Exactly one public certificate; a chain must not expand the invitation's trust.
	if pem.length() > 4096 or not pem.begins_with("-----BEGIN CERTIFICATE-----\n") \
		or not pem.ends_with("-----END CERTIFICATE-----\n") \
		or pem.count("-----BEGIN") != 1 or pem.count("-----END") != 1:
		return {}
	data["fingerprint"] = pem.sha256_text()
	return data


## The bounded JSON inside an invitation's text, unchecked; {} if none.
static func _decode(invitation: String) -> Dictionary:
	if invitation.length() > MAX_LENGTH or not invitation.begins_with(PREFIX):
		return {}
	var encoded := invitation.substr(PREFIX.length())
	if encoded.is_empty() or encoded.length() % 4 != 0:
		return {}
	for character in encoded:
		if not "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=".contains(character):
			return {}
	var bytes := Marshalls.base64_to_raw(encoded)
	if bytes.has(0) or Marshalls.raw_to_base64(bytes) != encoded:
		return {}
	return SgProtocol.decode_payload(bytes, 2)


## The protocol version an invitation was made by, read no further
## (2026-10-03): another version's invitation fails [method parse], and was
## refused as incomplete; this lets the lobby name both versions instead.
## 0 when the text is no invitation at all.
static func protocol(invitation: String) -> int:
	var data := _decode(invitation)
	return int(data.v) if SgProtocol.integer(data.get("v"), 1) else 0


## Why an invitation of [param version] cannot be used here, or "".
static func version_mismatch(version: int) -> String:
	if version == 0 or version == SgProtocol.VERSION: return ""
	return "This invitation is from %s version of Shandalar (SGManalink protocol %d; you run %d). Both players need the same version." \
		% ["an older" if version < SgProtocol.VERSION else "a newer", version, SgProtocol.VERSION]


static func certificate(data: Dictionary) -> X509Certificate:
	var cert := X509Certificate.new()
	if cert.load_from_string(String(data.get("certificate", ""))) != OK:
		return null
	return cert
