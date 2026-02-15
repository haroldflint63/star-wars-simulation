/// Daily task schedules for Star Wars heroes
class DailyTaskSchedule {
  static const Map<String, List<String>> agentTasks = {
    'luke': [
      '06:00 - Meditation and Force training on Dagobah',
      '08:00 - Lightsaber practice at Jedi Temple',
      '09:30 - Combat training - sparring with droids',
      '10:00 - Strategic meeting at Echo Base',
      '12:00 - Study ancient Jedi texts',
      '14:00 - Pilot training in X-Wing',
      '15:30 - Lightsaber dueling practice',
      '16:00 - Discuss plans with Rebellion leaders',
      '18:00 - Visit Yoda for wisdom on Dagobah',
      '19:30 - Advanced combat drills at Death Star',
      '20:00 - Evening reflection at Jedi Temple',
    ],
    'leia': [
      '05:30 - Review Rebellion intelligence reports',
      '07:00 - Diplomatic breakfast at Naboo Palace',
      '09:00 - Command briefing at Echo Base',
      '11:00 - Secret meeting at Mos Eisley Cantina',
      '13:00 - Coordinate fleet movements',
      '15:00 - Inspect defenses at Cloud City',
      '17:00 - Rally troops on Endor',
      '19:00 - Strategic planning session',
    ],
    'han': [
      '07:00 - Millennium Falcon maintenance check',
      '09:00 - Smuggling deal at Mos Eisley Cantina',
      '11:00 - Cargo delivery to Cloud City',
      '13:00 - Repair Falcon on Hoth',
      '15:00 - Negotiate with Jabba contacts',
      '17:00 - Scout mission on Endor',
      '19:00 - Evening at cantina with Chewbacca',
      '21:00 - Prepare for next hyperspace jump',
    ],
  };

  static String getCurrentTask(String agentId, int tick) {
    final tasks = agentTasks[agentId] ?? [];
    if (tasks.isEmpty) return 'Exploring the galaxy';

    // Cycle through tasks based on simulation tick
    final index = tick % tasks.length;
    return tasks[index];
  }

  static List<String> getTasksForAgent(String agentId) {
    return agentTasks[agentId] ?? ['No mission scheduled'];
  }

  static String getTaskDescription(String agentId, int tick) {
    final task = getCurrentTask(agentId, tick);

    // Extract activity from task
    if (task.contains('training') || task.contains('practice')) {
      return 'training with lightsaber';
    } else if (task.contains('Cantina') || task.contains('meeting')) {
      return 'meeting with allies';
    } else if (task.contains('Falcon') || task.contains('Pilot')) {
      return 'piloting spacecraft';
    } else if (task.contains('Force') || task.contains('Meditation')) {
      return 'meditating with the Force';
    } else if (task.contains('briefing') || task.contains('Command')) {
      return 'commanding Rebellion forces';
    } else if (task.contains('Smuggling') || task.contains('deal')) {
      return 'negotiating trade deals';
    } else if (task.contains('Yoda') || task.contains('wisdom')) {
      return 'seeking Jedi wisdom';
    } else if (task.contains('texts') || task.contains('Study')) {
      return 'studying ancient knowledge';
    } else {
      return 'on a galactic mission';
    }
  }
}
