import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/tracker_repository.dart';
import '../firebase_config.dart';
import '../sync/auth_service.dart';
import '../sync/group_service.dart';

// ============================================================
// SINCRONIZACIÓN ENTRE DISPOSITIVOS
// ============================================================

class SyncScreen extends StatefulWidget {
  final String? activeGroupId;

  // Lo que hay guardado en el teléfono ahora mismo. Se usa para
  // ofrecer subirlo al crear un grupo nuevo.
  final TrackerData localData;

  final Future<void> Function(String groupId, bool uploadLocalData)
  onGroupJoined;

  final Future<void> Function() onGroupLeft;

  const SyncScreen({
    super.key,
    required this.activeGroupId,
    required this.localData,
    required this.onGroupJoined,
    required this.onGroupLeft,
  });

  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final _auth = AuthService.instance;
  final _groups = GroupService.instance;

  bool _busy = true;
  String? _error;

  User? _user;
  PlayGroup? _group;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    if (!isFirebaseConfigured || !isGoogleSignInConfigured) {
      setState(() => _busy = false);
      return;
    }

    try {
      await _auth.ensureInitialized();

      _user = _auth.currentUser;

      if (_user != null && widget.activeGroupId != null) {
        _group = await _groups.fetchGroup(widget.activeGroupId!);
      }
    } on SyncException catch (error) {
      _error = error.message;
    }

    if (mounted) setState(() => _busy = false);
  }

  // Envuelve cualquier operación: apaga la pantalla, captura el error
  // y lo muestra con un mensaje legible.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await action();
    } on SyncException catch (error) {
      _error = error.message;
    } catch (error) {
      _error = 'Error inesperado: $error';
    }

    if (mounted) setState(() => _busy = false);
  }

  Future<void> _signIn() {
    return _run(() async {
      _user = await _auth.signInWithGoogle();
    });
  }

  Future<void> _signOut() {
    return _run(() async {
      await widget.onGroupLeft();
      await _auth.signOut();
      _user = null;
      _group = null;
    });
  }

  Future<void> _createGroup() async {
    final controller = TextEditingController();

    bool uploadLocal = !widget.localData.isEmpty;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nuevo grupo'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del grupo',
                      hintText: 'Ej: Los del jueves',
                    ),
                  ),

                  if (!widget.localData.isEmpty) ...[
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: uploadLocal,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Subir los datos de este teléfono'),
                      subtitle: Text(
                        '${widget.localData.players.length} jugadores • '
                        '${widget.localData.decks.length} mazos • '
                        '${widget.localData.matches.length} partidas',
                      ),
                      onChanged: (value) {
                        setDialogState(() => uploadLocal = value ?? false);
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    final name = controller.text.trim();

    controller.dispose();

    if (confirmed != true || name.isEmpty) return;

    await _run(() async {
      final group = await _groups.createGroup(name);

      await widget.onGroupJoined(group.id, uploadLocal);

      _group = group;
    });
  }

  Future<void> _joinGroup() async {
    final controller = TextEditingController();

    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Entrar a un grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Código',
                  hintText: 'Ej: A7K2QP',
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Los datos del grupo van a reemplazar lo que ves en la '
                'app. Lo que tenías guardado en este teléfono queda '
                'intacto y vuelve si salís del grupo.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Entrar'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (code == null || code.trim().isEmpty) return;

    await _run(() async {
      final group = await _groups.joinGroup(code);

      // Nunca subimos los datos locales al entrar a un grupo que ya
      // existe: duplicaría todos los jugadores.
      await widget.onGroupJoined(group.id, false);

      _group = group;
    });
  }

  Future<void> _leaveGroup() async {
    final group = _group;

    if (group == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('¿Salir del grupo?'),
          content: Text(
            'Vas a dejar de ver los datos de "${group.name}" y la app '
            'vuelve a los datos guardados en este teléfono.\n\n'
            'El historial del grupo no se borra: podés volver a entrar '
            'con el código ${group.id}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Salir'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    await _run(() async {
      await _groups.leaveGroup(group.id);
      await widget.onGroupLeft();
      _group = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('☁️ Sincronización')),
      body: _busy
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: _body()),
    );
  }

  List<Widget> _body() {
    if (!isFirebaseConfigured || !isGoogleSignInConfigured) {
      return [_notConfiguredCard()];
    }

    return [
      if (_error != null) _errorCard(_error!),

      if (_user == null) ..._signedOutBody() else ..._signedInBody(),
    ];
  }

  Widget _notConfiguredCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cloud_off),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Sincronización sin configurar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'La app está funcionando en modo local: los datos se '
              'guardan solo en este teléfono.\n\n'
              'Para compartir el historial con el grupo hay que '
              'conectar un proyecto de Firebase (es gratis). Los pasos '
              'están en SETUP.md, en la raíz del repositorio:',
            ),
            const SizedBox(height: 12),
            const Text(
              '1. flutterfire configure\n'
              '2. Activar Google como proveedor de login\n'
              '3. Registrar la huella SHA-1\n'
              '4. Completar googleWebClientId en lib/firebase_config.dart\n'
              '5. Publicar firestore.rules',
              style: TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Card(
      color: Colors.red.shade900,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  List<Widget> _signedOutBody() {
    return [
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jugá en varios teléfonos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Iniciá sesión y creá un grupo para que todo el grupo '
                'vea el mismo ranking, los mismos mazos y el mismo '
                'historial desde su propio teléfono.\n\n'
                'Las partidas registradas sin señal se sincronizan '
                'solas cuando vuelve la conexión.',
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _signIn,
          icon: const Icon(Icons.login),
          label: const Text('Iniciar sesión con Google'),
        ),
      ),
    ];
  }

  List<Widget> _signedInBody() {
    final user = _user!;
    final group = _group;

    return [
      Card(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user.displayName ?? 'Sin nombre'),
          subtitle: Text(user.email ?? ''),
          trailing: TextButton(
            onPressed: _signOut,
            child: const Text('Salir'),
          ),
        ),
      ),

      const SizedBox(height: 16),

      if (group == null) ..._noGroupBody() else ..._groupBody(group),
    ];
  }

  List<Widget> _noGroupBody() {
    return [
      const Text(
        'Todavía no estás en ningún grupo',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 12),

      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _createGroup,
          icon: const Icon(Icons.group_add),
          label: const Text('Crear un grupo'),
        ),
      ),

      const SizedBox(height: 10),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _joinGroup,
          icon: const Icon(Icons.login),
          label: const Text('Entrar con un código'),
        ),
      ),
    ];
  }

  List<Widget> _groupBody(PlayGroup group) {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_done, color: Colors.green),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              const Text('Código para invitar:'),

              const SizedBox(height: 6),

              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      group.id,
                      style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'Copiar código',
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: group.id));

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Código copiado.')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      const SizedBox(height: 16),

      const Text(
        'Miembros',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),

      const SizedBox(height: 8),

      StreamBuilder<List<GroupMember>>(
        stream: _groups.watchMembers(group.id),
        builder: (context, snapshot) {
          final members = snapshot.data ?? const <GroupMember>[];

          if (members.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Cargando…'),
            );
          }

          return Column(
            children: members.map((member) {
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(member.displayName),
                  trailing: member.uid == group.ownerUid
                      ? const Text('Creador')
                      : null,
                ),
              );
            }).toList(),
          );
        },
      ),

      const SizedBox(height: 16),

      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _leaveGroup,
          icon: const Icon(Icons.logout),
          label: const Text('Salir del grupo'),
        ),
      ),
    ];
  }
}
