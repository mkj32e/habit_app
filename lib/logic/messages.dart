import 'dart:math';

import '../models/habit.dart';
import 'stats.dart';

/// Placeholders usable in every notification text.
const kPlaceholders = <String, String>{
  '{habitude}': 'Nom de l\'habitude',
  '{emoji}': 'Emoji',
  '{serie}': 'Série actuelle',
  '{record}': 'Meilleure série',
  '{pourquoi}': 'Ta motivation',
  '{identite}': 'Ton identité visée',
  '{declencheur}': 'Ton déclencheur',
  '{lieu}': 'Le lieu',
  '{mini}': 'Version 2 minutes',
  '{restant}': 'Répétitions restantes',
  '{objectif}': 'Objectif du jour',
  '{prenom}': 'Ton prénom',
  '{n}': 'N° du rappel',
};

String renderMessage(
  String template,
  Habit h, {
  HabitStats? stats,
  String userName = '',
  int n = 1,
  int done = 0,
}) {
  final s = stats ?? computeStats(h);
  final remaining = max(0, h.target - done);
  final values = <String, String>{
    '{habitude}': h.name,
    '{emoji}': h.emoji,
    '{serie}': '${s.currentStreak}',
    '{record}': '${s.bestStreak}',
    '{pourquoi}': h.why.isEmpty ? 'chaque petit pas compte.' : h.why,
    '{identite}': h.identity.isEmpty ? 'tient ses engagements' : h.identity,
    '{declencheur}': h.cue,
    '{lieu}': h.location,
    '{mini}': h.miniVersion.isEmpty ? 'commence juste 2 minutes.' : h.miniVersion,
    '{restant}': h.unit.isEmpty ? '$remaining' : '$remaining ${h.unit}',
    '{objectif}': h.unit.isEmpty ? '${h.target}' : '${h.target} ${h.unit}',
    '{prenom}': userName.isEmpty ? 'champion' : userName,
    '{n}': '$n',
  };
  var out = template;
  values.forEach((k, v) => out = out.replaceAll(k, v));
  return out.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
}

/// Variable rewards: a random message after each completion keeps it fresh.
const kRewardMessages = [
  'Bien joué ! Un vote de plus pour la personne que tu deviens.',
  'Et de un ! La constance bat l\'intensité.',
  'Boom 💥 Ta série grandit.',
  'Tu viens de prouver que tu peux compter sur toi.',
  'Chaque répétition renforce le circuit. Continue !',
  '1 % meilleur qu\'hier. C\'est comme ça qu\'on gagne.',
  'Respect. La plupart abandonnent, pas toi.',
  'Les petites victoires construisent les grandes.',
  'Ton futur toi te remercie 🙏',
  'Validé ✔︎ Le plus dur, c\'était de commencer.',
];

const kPerfectDayMessages = [
  'Journée parfaite ! Tout est validé 🌟',
  '100 % aujourd\'hui. Savoure ce moment.',
  'Grand chelem ! Rien ne t\'arrête.',
];

/// Short daily principles (habit psychology), one per day.
const kPrinciples = [
  ('Ne rate jamais deux fois', 'Rater une fois est un accident. Rater deux fois, c\'est le début d\'une nouvelle (mauvaise) habitude.'),
  ('La règle des 2 minutes', 'Une habitude doit pouvoir commencer en moins de 2 minutes. Réduis-la jusqu\'à ce que ce soit ridiculement facile.'),
  ('Vote pour ton identité', 'Chaque action est un vote pour la personne que tu veux devenir. Tu n\'as pas besoin de l\'unanimité, juste de la majorité.'),
  ('Empile tes habitudes', '"Après [habitude actuelle], je ferai [nouvelle habitude]." Ancre le nouveau dans l\'existant.'),
  ('Rends-le évident', 'Prépare ton environnement : laisse le livre sur l\'oreiller, les baskets devant la porte.'),
  ('Intention de mise en œuvre', 'Les gens qui écrivent quand et où ils agiront ont 2 à 3 fois plus de chances de le faire.'),
  ('Le plateau du potentiel latent', 'Les résultats arrivent en retard. Le travail n\'est pas perdu, il s\'accumule.'),
  ('Ne casse pas la chaîne', 'Chaque jour coché rend le suivant plus facile. Protège ta série.'),
  ('Systèmes > objectifs', 'Tu ne t\'élèves pas au niveau de tes objectifs, tu tombes au niveau de tes systèmes.'),
  ('Rends-le satisfaisant', 'On répète ce qui est récompensé immédiatement. Savoure chaque validation.'),
  ('L\'effet nouveau départ', 'Lundi, le 1er du mois, un anniversaire : profite des nouveaux départs pour relancer.'),
  ('Responsabilité sociale', 'Savoir que quelqu\'un regarde double la motivation. Partage tes défis avec tes amis.'),
  ('Sois indulgent', 'L\'autocritique fait abandonner. L\'auto-compassion fait recommencer.'),
  ('La moitié, c\'est mieux que rien', 'Un jour sans motivation ? Fais la version mini. Garder le rythme compte plus que la performance.'),
];

(String, String) principleOfTheDay([DateTime? now]) {
  final d = now ?? DateTime.now();
  final idx = (d.year * 400 + d.month * 31 + d.day) % kPrinciples.length;
  return kPrinciples[idx];
}

String randomOf(List<String> l) => l[Random().nextInt(l.length)];
