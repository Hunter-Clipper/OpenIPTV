// OpenVPN 3 core <-> Android bridge for OpenIPTV's built-in OpenVPN
// (Settings -> Power User Tools, #41). OpenVPN 3 is used under its MPL-2.0
// option (GPL-3.0-compatible), with mbed TLS (Apache-2.0).
//
// The core runs one session at a time on the calling (worker) thread. The
// tunnel settings the server pushes are collected here and handed to
// Kotlin in one call at establish time; Kotlin builds the Android
// VpnService interface and returns its file descriptor. The core's own
// UDP/TCP socket is "protected" through Kotlin so it bypasses the tunnel.

#include <jni.h>
#include <android/log.h>

#include <atomic>
#include <mutex>
#include <sstream>
#include <string>
#include <vector>

#include <client/ovpncli.cpp>  // the core's client API, compiled into this unit

namespace {

JavaVM *g_vm = nullptr;

void logi(const std::string &s) {
  __android_log_print(ANDROID_LOG_INFO, "OTV-ovpn", "%s", s.c_str());
}

// Minimal JSON string escaping for the settings we pass to Kotlin.
std::string esc(const std::string &s) {
  std::string o;
  for (char c : s) {
    switch (c) {
      case '"': o += "\\\""; break;
      case '\\': o += "\\\\"; break;
      case '\n': o += "\\n"; break;
      default: o += c;
    }
  }
  return o;
}

struct Route {
  std::string address;
  int prefix;
  bool ipv6;
  bool exclude;
};

class Client : public openvpn::ClientAPI::OpenVPNClient {
 public:
  Client(JNIEnv *env, jobject callback) {
    callback_ = env->NewGlobalRef(callback);
    jclass cls = env->GetObjectClass(callback);
    establish_ = env->GetMethodID(cls, "establish", "(Ljava/lang/String;)I");
    protect_ = env->GetMethodID(cls, "protect", "(I)Z");
    event_ = env->GetMethodID(cls, "onEvent",
                              "(Ljava/lang/String;Ljava/lang/String;ZZ)V");
  }

  ~Client() override {
    JNIEnv *env = attach();
    if (env != nullptr && callback_ != nullptr) env->DeleteGlobalRef(callback_);
  }

  // --- tun builder: collect, then establish via Kotlin ---------------------

  bool tun_builder_new() override {
    addresses_.clear();
    routes_.clear();
    dns_.clear();
    domains_.clear();
    mtu_ = 0;
    reroute4_ = reroute6_ = false;
    return true;
  }

  bool tun_builder_add_address(const std::string &address, int prefix,
                               const std::string &, bool ipv6,
                               bool) override {
    addresses_.push_back({address, prefix, ipv6, false});
    return true;
  }

  bool tun_builder_reroute_gw(bool ipv4, bool ipv6, unsigned int) override {
    reroute4_ = reroute4_ || ipv4;
    reroute6_ = reroute6_ || ipv6;
    return true;
  }

  bool tun_builder_add_route(const std::string &address, int prefix, int,
                             bool ipv6) override {
    routes_.push_back({address, prefix, ipv6, false});
    return true;
  }

  bool tun_builder_exclude_route(const std::string &address, int prefix, int,
                                 bool ipv6) override {
    routes_.push_back({address, prefix, ipv6, true});
    return true;
  }

  bool tun_builder_set_dns_options(
      const openvpn::DnsOptions &dns) override {
    for (const auto &[prio, server] : dns.servers) {
      for (const auto &a : server.addresses) dns_.push_back(a.address);
    }
    for (const auto &d : dns.search_domains) domains_.push_back(d.domain);
    return true;
  }

  bool tun_builder_set_mtu(int mtu) override {
    mtu_ = mtu;
    return true;
  }

  bool tun_builder_set_remote_address(const std::string &, bool) override {
    return true;
  }
  bool tun_builder_set_session_name(const std::string &) override {
    return true;
  }
  bool tun_builder_set_layer(int layer) override { return layer == 3; }
  bool tun_builder_add_wins_server(const std::string &) override {
    return true;
  }
  bool tun_builder_set_allow_family(int, bool) override { return true; }
  bool tun_builder_set_allow_local_dns(bool) override { return true; }
  bool tun_builder_add_proxy_bypass(const std::string &) override {
    return true;
  }

  int tun_builder_establish() override {
    std::ostringstream j;
    j << "{\"mtu\":" << mtu_ << ",\"reroute4\":" << (reroute4_ ? "true" : "false")
      << ",\"reroute6\":" << (reroute6_ ? "true" : "false") << ",\"addresses\":[";
    for (size_t i = 0; i < addresses_.size(); i++) {
      const auto &a = addresses_[i];
      j << (i ? "," : "") << "{\"a\":\"" << esc(a.address) << "\",\"p\":" << a.prefix
        << ",\"v6\":" << (a.ipv6 ? "true" : "false") << "}";
    }
    j << "],\"routes\":[";
    for (size_t i = 0; i < routes_.size(); i++) {
      const auto &r = routes_[i];
      j << (i ? "," : "") << "{\"a\":\"" << esc(r.address) << "\",\"p\":" << r.prefix
        << ",\"v6\":" << (r.ipv6 ? "true" : "false")
        << ",\"x\":" << (r.exclude ? "true" : "false") << "}";
    }
    j << "],\"dns\":[";
    for (size_t i = 0; i < dns_.size(); i++) j << (i ? "," : "") << "\"" << esc(dns_[i]) << "\"";
    j << "],\"domains\":[";
    for (size_t i = 0; i < domains_.size(); i++) j << (i ? "," : "") << "\"" << esc(domains_[i]) << "\"";
    j << "]}";

    JNIEnv *env = attach();
    if (env == nullptr) return -1;
    jstring js = env->NewStringUTF(j.str().c_str());
    jint fd = env->CallIntMethod(callback_, establish_, js);
    env->DeleteLocalRef(js);
    if (env->ExceptionCheck()) {
      env->ExceptionClear();
      return -1;
    }
    return fd;
  }

  bool tun_builder_persist() override { return false; }

  // --- the rest of the client ----------------------------------------------

  bool socket_protect(openvpn_io::detail::socket_type socket, std::string,
                      bool) override {
    JNIEnv *env = attach();
    if (env == nullptr) return false;
    jboolean ok = env->CallBooleanMethod(callback_, protect_, (jint)socket);
    if (env->ExceptionCheck()) {
      env->ExceptionClear();
      return false;
    }
    return ok;
  }

  bool pause_on_connection_timeout() override { return false; }

  void event(const openvpn::ClientAPI::Event &ev) override {
    JNIEnv *env = attach();
    if (env == nullptr) return;
    jstring name = env->NewStringUTF(ev.name.c_str());
    jstring info = env->NewStringUTF(ev.info.c_str());
    env->CallVoidMethod(callback_, event_, name, info, (jboolean)ev.error,
                        (jboolean)ev.fatal);
    env->DeleteLocalRef(name);
    env->DeleteLocalRef(info);
    if (env->ExceptionCheck()) env->ExceptionClear();
  }

  void log(const openvpn::ClientAPI::LogInfo &li) override { logi(li.text); }
  void acc_event(const openvpn::ClientAPI::AppCustomControlMessageEvent &) override {}
  void external_pki_cert_request(openvpn::ClientAPI::ExternalPKICertRequest &r) override {
    r.error = true;
    r.errorText = "external PKI not supported";
  }
  void external_pki_sign_request(openvpn::ClientAPI::ExternalPKISignRequest &r) override {
    r.error = true;
    r.errorText = "external PKI not supported";
  }

 private:
  static JNIEnv *attach() {
    JNIEnv *env = nullptr;
    if (g_vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) == JNI_OK) {
      return env;
    }
    return g_vm->AttachCurrentThread(&env, nullptr) == JNI_OK ? env : nullptr;
  }

  jobject callback_ = nullptr;
  jmethodID establish_ = nullptr;
  jmethodID protect_ = nullptr;
  jmethodID event_ = nullptr;

  std::vector<Route> addresses_;
  std::vector<Route> routes_;
  std::vector<std::string> dns_;
  std::vector<std::string> domains_;
  int mtu_ = 0;
  bool reroute4_ = false;
  bool reroute6_ = false;
};

std::mutex g_mutex;
Client *g_client = nullptr;  // the running session, for stop() / stats()

std::string str(JNIEnv *env, jstring s) {
  if (s == nullptr) return {};
  const char *c = env->GetStringUTFChars(s, nullptr);
  std::string out(c);
  env->ReleaseStringUTFChars(s, c);
  return out;
}

}  // namespace

extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *) {
  g_vm = vm;
  return JNI_VERSION_1_6;
}

// Checks a profile without connecting. Returns "" when usable, else a
// short reason (also "needs_login" when the profile asks for a username
// and password and none were given).
JNIEXPORT jstring JNICALL
Java_com_openiptv_app_OpenVpnNative_validate(JNIEnv *env, jclass, jstring profile) {
  openvpn::ClientAPI::Config config;
  config.content = str(env, profile);
  openvpn::ClientAPI::EvalConfig eval =
      openvpn::ClientAPI::OpenVPNClientHelper().eval_config(config);
  if (eval.error) return env->NewStringUTF(eval.message.c_str());
  std::string out = eval.autologin ? "" : "needs_login";
  if (eval.externalPki) out = "external_pki";
  return env->NewStringUTF(out.c_str());
}

// Runs a session until it ends (blocking). Returns "" on a clean stop, else
// the core's error status.
JNIEXPORT jstring JNICALL
Java_com_openiptv_app_OpenVpnNative_run(JNIEnv *env, jclass, jstring profile,
                                        jstring user, jstring pass,
                                        jobject callback) {
  Client client(env, callback);
  openvpn::ClientAPI::Config config;
  config.content = str(env, profile);
  config.guiVersion = "OpenIPTV";
  config.googleDnsFallback = false;
  // Give up (CONNECTION_TIMEOUT) instead of retrying forever when the server
  // can't be reached; an established session still reconnects on its own.
  config.connTimeout = 45;
  openvpn::ClientAPI::EvalConfig eval = client.eval_config(config);
  if (eval.error) return env->NewStringUTF(("config: " + eval.message).c_str());
  if (!eval.autologin) {
    openvpn::ClientAPI::ProvideCreds creds;
    creds.username = str(env, user);
    creds.password = str(env, pass);
    openvpn::ClientAPI::Status s = client.provide_creds(creds);
    if (s.error) return env->NewStringUTF(("creds: " + s.message).c_str());
  }
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_client = &client;
  }
  openvpn::ClientAPI::Status status = client.connect();
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_client = nullptr;
  }
  if (status.error) {
    std::string s = status.status.empty() ? status.message : status.status + ": " + status.message;
    return env->NewStringUTF(s.c_str());
  }
  return env->NewStringUTF("");
}

JNIEXPORT void JNICALL Java_com_openiptv_app_OpenVpnNative_stop(JNIEnv *, jclass) {
  std::lock_guard<std::mutex> lock(g_mutex);
  if (g_client != nullptr) g_client->stop();
}

// [bytesIn, bytesOut], or [-1, -1] when no session is running.
JNIEXPORT jlongArray JNICALL
Java_com_openiptv_app_OpenVpnNative_stats(JNIEnv *env, jclass) {
  jlong v[2] = {-1, -1};
  {
    std::lock_guard<std::mutex> lock(g_mutex);
    if (g_client != nullptr) {
      openvpn::ClientAPI::TransportStats t = g_client->transport_stats();
      v[0] = t.bytesIn;
      v[1] = t.bytesOut;
    }
  }
  jlongArray out = env->NewLongArray(2);
  env->SetLongArrayRegion(out, 0, 2, v);
  return out;
}

}  // extern "C"
