import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../common/l10n.dart';
import 'ica_auth.dart';

/// ICA's own login page, shown so that this app never handles the
/// password.
///
/// The page is served by icagruppen.se and is the same one their app
/// uses. What happens here is theirs: the personnummer, the password,
/// whatever they ask next. This view watches only for the navigation to
/// `icacurity://app`, which is the identity server handing back an
/// authorization code, and reads the code out of the address.
///
/// Nothing claims that scheme with the operating system, deliberately.
/// Claiming it would collide with ICA's own app on a phone that has both,
/// and there is no need: the redirect is never followed, only seen.
///
/// **No JavaScript is injected into this page and none ever should be.**
/// The whole point of showing their form rather than ours is that the
/// credential passes through nothing of ours; a script here would quietly
/// undo that.
class IcaLoginScreen extends ConsumerStatefulWidget {
  const IcaLoginScreen({super.key, required this.login});

  final IcaLogin login;

  /// Shows the login and returns the code, or null if it was abandoned.
  static Future<String?> show(BuildContext context, IcaLogin login) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => IcaLoginScreen(login: login)),
      );

  @override
  ConsumerState<IcaLoginScreen> createState() => _IcaLoginScreenState();
}

class _IcaLoginScreenState extends ConsumerState<IcaLoginScreen> {
  late final WebViewController _web;
  bool _loading = true;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onNavigationRequest: (request) {
            if (!request.url.startsWith(IcaAuth.redirectUri)) {
              return NavigationDecision.navigate;
            }
            _finish(Uri.parse(request.url));
            // Never followed: there is nothing at that address, and
            // following it is what would need the scheme registered.
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(widget.login.authorizeUrl);
  }

  void _finish(Uri redirect) {
    if (_done) return;
    _done = true;
    final code = redirect.queryParameters['code'];
    final state = redirect.queryParameters['state'];
    // A code under a state we did not send belongs to someone else's
    // login. Refused rather than exchanged.
    final ours = state == null || state == widget.login.state;
    if (mounted) Navigator.of(context).pop(ours ? code : null);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.icaSignIn),
        bottom: _loading
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: Column(
        children: [
          // Said plainly, because a login page inside another app is
          // exactly the shape a phishing screen has. The person should
          // know why it is here and what this app can see.
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.all(12),
            child: Text(
              l10n.icaSignInNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(child: WebViewWidget(controller: _web)),
        ],
      ),
    );
  }
}
