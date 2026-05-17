# Architecture Decision Record — State Management

## Rule: Firestore Never in `build()`

Firestore streams must never be subscribed inside a `build()` method. Every `build()` call creates a new subscription; widgets rebuild frequently (theme change, MediaQuery, orientation, parent rebuild). The result is subscription leaks and doubled network traffic.

The correct boundary: **all Firestore calls live in a Notifier**. Widgets read state, they do not create streams.

---

## The Four Layers

```
Widget  →  Notifier  →  Repository  →  Firestore
 (UI)     (state)     (data access)    (source)
```

| Layer | Responsibility | May call |
|---|---|---|
| Widget | Render state, dispatch user events | Notifier methods only |
| Notifier | Hold state, subscribe to streams, run async ops | Repository only |
| Repository | Wrap Firestore; return `Stream<T>` or `Future<T>` | Firestore SDK only |
| Firestore | Cloud data | — |

---

## When to Use StreamBuilder vs Consumer

**Always use `Consumer` / `context.watch<T>()`.**

`StreamBuilder` is allowed only for a stream that is genuinely owned by the widget itself (e.g. an animation controller stream). It must never be used to subscribe to Firestore.

---

## WRONG — StreamBuilder directly in build()

```dart
// ❌ details_page.dart (before migration)
class _DetailsPageState extends State<DetailsPage> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Mosque?>(
      // New subscription created on every rebuild — leaks.
      stream: ServiceLocator.get<MosqueRepository>().getMosqueStream(widget.docId),
      builder: (context, snapshot) {
        return StreamBuilder<bool>(
          // Another subscription nested inside — compounds the problem.
          stream: MosqueFollowService.isFollowingStream(widget.docId),
          builder: (context, snap) {
            // UI here
          },
        );
      },
    );
  }
}
```

Problems:
- Every rebuild subscribes again; subscriptions are never cancelled.
- Business logic (auto-verification) lives in the widget.
- Three nested `StreamBuilder` layers obscure intent.

---

## RIGHT — Consumer reads notifier state

```dart
// ✅ details_page.dart (after migration)

// Entry point: StatelessWidget creates and provides the notifier.
class DetailsPage extends StatelessWidget {
  final Map<String, dynamic> data;
  final String docId;
  const DetailsPage({super.key, required this.data, required this.docId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MosqueDetailsNotifier(
        mosqueRepository: ServiceLocator.get<MosqueRepository>(),
        janazaRepository: ServiceLocator.get<JanazaRepository>(),
      )..init(docId, data),
      child: _DetailsView(docId: docId, initialData: data),
    );
  }
}

// Pure view: reads notifier, no Firestore, no async.
class _DetailsView extends StatelessWidget {
  const _DetailsView({required this.docId, required this.initialData});
  final String docId;
  final Map<String, dynamic> initialData;

  @override
  Widget build(BuildContext context) {
    final n = context.watch<MosqueDetailsNotifier>();
    final docData = n.mosque?.raw ?? initialData;
    // render docData, n.isFollowing, n.janazaAnnouncements — zero StreamBuilders
  }
}
```

---

## Notifier Pattern

Extend `BaseNotifier` (see `lib/core/base/base_notifier.dart`).

```dart
class MyNotifier extends BaseNotifier {
  final MyRepository _repo;
  SomeModel? _data;
  SomeModel? get data => _data;

  MyNotifier({required MyRepository repo}) : _repo = repo;

  void init(String id) {
    // listenToStream stores the subscription and cancels it in dispose().
    listenToStream(_repo.stream(id), onData: (val) {
      _data = val;
      notifyListeners();
    });
  }

  Future<void> doSomething() async {
    // runAsync manages loading/error state and calls notifyListeners().
    await runAsync(() async {
      await _repo.update(_data!.id, {'field': 'value'});
    });
  }
}
```

---

## Providing a Notifier

Use `ChangeNotifierProvider(create:)` at the page level. The `create` callback ensures the notifier is disposed when the route is popped.

```dart
ChangeNotifierProvider(
  create: (_) => MyNotifier(repo: ServiceLocator.get<MyRepository>())..init(id),
  child: const _MyView(),
)
```

Never use `ChangeNotifierProvider.value` for page-level notifiers — it does not dispose.

---

## Pages Still Needing Migration

| File | Line | Violation |
|---|---|---|
| `features/home/home_page.dart` | 422 | `FirebaseAuth.authStateChanges()` |
| `features/home/home_page.dart` | 433 | `UserProfile` stream |
| `features/home/home_page.dart` | 584 | `QuerySnapshot` |
| `features/notifications/notifications_page.dart` | 129 | Unread count stream |
| `features/notifications/notifications_page.dart` | 150 | `List<AppNotification>` stream |
| `core/navigation/main_navigation.dart` | 255 | `AdService.monetizationStream()` |
| `features/auth/screens/auth_page.dart` | 1046 | `FirebaseAuth.authStateChanges()` |
| `features/auth/screens/auth_page.dart` | 1305 | `UserProfile` stream |
| `widgets/mosque_follow_button.dart` | 13 | `isFollowingStream()` |

Apply the same pattern to each: extract a notifier, move streams to `listenToStream`, replace `StreamBuilder` with `context.watch`.
