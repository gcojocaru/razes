import { BALANCE as B } from './balance';
import type { GameEvent, GameState } from './types';

export const EVENTS: Record<string, GameEvent> = {
  'spring-ox': {
    id: 'spring-ox',
    eyebrow: 'A neighbour at the gate',
    title: 'A favour in the furrows',
    person: 'vasile',
    text: 'Vasile rests a hand on the gate. “That field is too much for a spade alone. Take my ox for the sowing. Come harvest, you can send someone to help me.” Behind him, the earth is finally beginning to soften.',
    choices: [
      {
        id: 'borrow',
        label: 'Accept his kindness',
        detail: `+${B.oxBonus} potential harvest · owe one adult in autumn`,
        effect: { ox: 'borrowed' },
        memory: {
          title: 'A promise to Vasile',
          detail:
            'One adult owed to the neighbour in autumn, in return for his ox this spring.',
          tone: 'neutral',
        },
      },
      {
        id: 'pay',
        label: 'Pay for the ox',
        detail: `−${B.oxPrice} money · +${B.oxBonus} potential harvest · no obligation`,
        effect: { money: -B.oxPrice, ox: 'paid' },
        memory: {
          title: 'An honest exchange',
          detail:
            'You paid to use Vasile’s ox for the spring work. Your autumn labour remains your own.',
          tone: 'neutral',
        },
      },
      {
        id: 'decline',
        label: 'Work with what we have',
        detail: 'No cost or promise · a smaller potential harvest',
        effect: { ox: 'declined' },
        memory: {
          title: 'Our own hands',
          detail:
            'You chose to plant without the ox, keeping your money and independence.',
          tone: 'neutral',
        },
      },
    ],
  },
  'spring-table': {
    id: 'spring-table',
    eyebrow: 'At the kitchen table',
    title: 'The first meal together',
    person: 'ana',
    text: 'Ana lays out the last of the old linen. “The house is ours now, but the days should be ours too. We need to speak of what each of us hopes to keep.” Vasile has left a small sack of grain by the door.',
    choices: [
      {
        id: 'share',
        label: 'Accept the grain with thanks',
        detail: `+${B.giftFood} food · remember Vasile’s kindness`,
        effect: { food: B.giftFood, trust: 1 },
        memory: {
          title: 'Bread at our table',
          detail:
            'Vasile shared grain in your first spring. Ana remembers the warmth of that evening.',
          tone: 'good',
        },
      },
      {
        id: 'keep',
        label: 'Keep our own table',
        detail: 'No resource change · preserve your independence',
        effect: {},
        memory: {
          title: 'A quiet beginning',
          detail:
            'You made your first meal from your own stores. Ana asked that decisions be shared.',
          tone: 'neutral',
        },
      },
    ],
  },
  'summer-brother': {
    id: 'summer-brother',
    eyebrow: 'A conversation in the shade',
    title: 'A place of his own',
    person: 'petru',
    text: 'Petru stops sharpening the sickle. “Father’s share came to both of us. I work these strips beside you. What part of the stores can I call my own?” He is not asking to leave. He wants a say in what the household keeps and spends.',
    choices: [
      {
        id: 'share',
        label: 'Promise him a fair share',
        detail: `−${B.brotherShare} money for his own needs · Petru contributes ${B.fairShareFood} food in autumn`,
        effect: { money: -B.brotherShare, fairShare: true },
        memory: {
          title: 'A brother, with a share',
          detail:
            'You set aside money for Petru’s own needs and recognised his place in household decisions. He will add provisions at harvest.',
          tone: 'good',
        },
      },
      {
        id: 'listen',
        label: 'Hear him, but keep the stores together',
        detail: 'No cost · the inheritance remains unresolved',
        effect: {},
        memory: {
          title: 'An unfinished conversation',
          detail:
            'You listened to Petru, but left his share undecided. He stayed, with questions.',
          tone: 'neutral',
        },
      },
    ],
  },
  'summer-tended': {
    id: 'summer-tended',
    eyebrow: 'Beneath a wide summer sky',
    title: 'What careful hands can do',
    person: 'ana',
    text: 'The rows stand straight and green. Ana brushes a seed head with her fingertips. “We did right by this patch of earth.” There is no harvest yet, but for the first time the field looks like a promise you can keep.',
    choices: [
      {
        id: 'accept',
        label: 'Let the crop ripen',
        detail: 'The tending bonus is already included in your autumn crop',
        effect: {},
        memory: {
          title: 'A well-tended field',
          detail:
            'You gave the crop the summer attention it needed. The larger harvest is ready for autumn.',
          tone: 'good',
        },
      },
    ],
  },
  'summer-dry': {
    id: 'summer-dry',
    eyebrow: 'The long, dry days',
    title: 'A field left waiting',
    person: 'ana',
    text: 'There was other work to do, and weeds found their way between the rows. Ana says nothing for a while. “We can still gather what grows. Let us be honest about how much that will be.”',
    choices: [
      {
        id: 'accept',
        label: 'Take stock and carry on',
        detail: 'No additional loss · the crop has no tending bonus',
        effect: {},
        memory: {
          title: 'Other work came first',
          detail:
            'Summer labour went elsewhere. The field’s potential remains smaller.',
          tone: 'neutral',
        },
      },
    ],
  },
  'autumn-promise': {
    id: 'autumn-promise',
    eyebrow: 'A promise comes due',
    title: 'The hand you promised',
    person: 'vasile',
    text: 'Vasile comes before sunrise. “My grain is ready. Yours too, by the look of it.” He does not mention the ox. He does not have to. Keeping your word will leave just two adults to bring your own harvest home.',
    choices: [
      {
        id: 'honour',
        label: 'Send Petru to help him',
        detail: 'Reserve Petru’s one assignment · keep the promise',
        effect: { ox: 'honoured', trust: 2, reserve: true },
        memory: {
          title: 'A promise kept',
          detail:
            'Petru helped Vasile at harvest. Your household had two adults left for its own work.',
          tone: 'good',
        },
      },
      {
        id: 'break',
        label: 'Keep everyone at home',
        detail:
          'All three adults available · Vasile will refuse winter assistance',
        effect: { ox: 'broken', trust: -3 },
        memory: {
          title: 'A promise broken',
          detail:
            'You kept the autumn worker you had promised. Vasile will remember when winter comes.',
          tone: 'bad',
        },
      },
    ],
  },
  'autumn-free': {
    id: 'autumn-free',
    eyebrow: 'The season of gathering',
    title: 'Before the first frost',
    person: 'ion',
    text: 'Mist sits low over the field. There is grain to gather, a house to prepare, and an old disagreement waiting at the village. No worker is promised elsewhere. How you spend these days is yours to decide.',
    choices: [
      {
        id: 'prepare',
        label: 'Gather the household',
        detail: 'Three adults available · harvest needs two assignments',
        effect: {},
      },
    ],
  },
  'autumn-dispute': {
    id: 'autumn-dispute',
    eyebrow: 'A visitor from the village',
    title: 'Where the furrow ends',
    person: 'dumitru',
    text: 'Dumitru has spoken with the cousin who shares your inherited land. The two households remember the boundary differently. “Let us walk it together, with neighbours to hear the agreement.” You can meet the expense now, or leave the conversation until spring.',
    choices: [
      {
        id: 'settle',
        label: 'Settle the disagreement',
        detail: `−${B.settlementCost} money · arrange a witnessed boundary agreement`,
        effect: { money: -B.settlementCost },
        memory: {
          title: 'A boundary settled',
          detail:
            'Dumitru brought the families and neighbours together. You agreed where your working strips meet. Next spring begins with one less argument.',
          tone: 'good',
        },
      },
      {
        id: 'keep',
        label: 'Leave it until spring',
        detail: 'No cost · the dispute remains part of your ending',
        effect: {},
        memory: {
          title: 'The disputed boundary',
          detail:
            'You kept your money. The inheritance disagreement will still need an answer next spring.',
          tone: 'neutral',
        },
      },
    ],
  },
  'winter-friend': {
    id: 'winter-friend',
    eyebrow: 'Footprints in the snow',
    title: 'A door that opens',
    person: 'vasile',
    text: 'Smoke rises from Vasile’s chimney. He opens the door before you knock. “Cold year,” he says, making room by the fire. The way you treated him in the warmer months has not been forgotten.',
    choices: [
      {
        id: 'ask',
        label: 'Ask for a little help',
        detail: `+${B.neighbourFood} food · accept a neighbour’s support`,
        effect: { food: B.neighbourFood },
        memory: {
          title: 'No winter alone',
          detail:
            'Vasile shared winter provisions. The relationship you kept became food on your table.',
          tone: 'good',
        },
      },
      {
        id: 'independent',
        label: 'Visit, but rely on our stores',
        detail: 'No resource change · keep the friendship',
        effect: {},
        memory: {
          title: 'A friendly fire',
          detail:
            'You shared a conversation with Vasile, then returned to your own provisions.',
          tone: 'good',
        },
      },
    ],
  },
  'winter-isolation': {
    id: 'winter-isolation',
    eyebrow: 'A quiet road',
    title: 'The weight of a broken word',
    person: 'vasile',
    text: 'Vasile meets you at the gate. “In autumn I needed a hand. You had given your word.” His voice is quiet. There is no grain offered today, only the space between what was promised and what was done.',
    choices: [
      {
        id: 'endure',
        label: 'Return home and make do',
        detail:
          'No winter assistance · your household can still work and buy supplies',
        effect: {},
        memory: {
          title: 'A closed door',
          detail:
            'Vasile refused winter help because the autumn promise was broken.',
          tone: 'bad',
        },
      },
    ],
  },
  'winter-hearth': {
    id: 'winter-hearth',
    eyebrow: 'The longest evening',
    title: 'A home worth keeping',
    person: 'ana',
    text: 'The roof holds. In the lamplight, Petru mends a handle while Ana sets three bowls on the table. “It was never only the house,” she says. Outside, beneath the snow, the field waits for another spring.',
    choices: [
      {
        id: 'together',
        label: 'Sit together by the fire',
        detail: 'Resolve winter consumption and see what the year has meant',
        effect: {},
        memory: {
          title: 'Three bowls by the fire',
          detail:
            'You ended the year together, remembering the work and the words that brought you here.',
          tone: 'good',
        },
      },
      {
        id: 'meal',
        label: 'Make a small celebration',
        detail: `−${B.winterMeal} food before winter consumption · a warm family memory`,
        effect: { food: -B.winterMeal },
        memory: {
          title: 'A meal to remember',
          detail:
            'You used a little extra food to celebrate a year together. Ana and Petru remember it.',
          tone: 'good',
        },
      },
    ],
  },
  'winter-cold': {
    id: 'winter-cold',
    eyebrow: 'The longest evening',
    title: 'Close around the embers',
    person: 'ana',
    text: 'The wind has found the seams in the old roof. You draw the chairs close to the fire. Ana passes Petru a blanket. “Whatever the spring brings, we will speak of it together.” For now, there is the work of staying warm.',
    choices: [
      {
        id: 'together',
        label: 'Share the warmth we have',
        detail: 'Cold shelter adds extra food consumption · resolve the year',
        effect: {},
        memory: {
          title: 'Close around the embers',
          detail:
            'The damaged house made winter harder. Your family stayed close around the remaining warmth.',
          tone: 'neutral',
        },
      },
    ],
  },
};

export function eventFor(s: GameState): GameEvent {
  if (s.phase !== 'opening' && s.phase !== 'consequence')
    throw new Error('There is no event to choose right now.');
  const opening = s.phase === 'opening';
  const id =
    s.season === 0
      ? opening
        ? 'spring-ox'
        : 'spring-table'
      : s.season === 1
        ? opening
          ? 'summer-brother'
          : s.tended
            ? 'summer-tended'
            : 'summer-dry'
        : s.season === 2
          ? opening
            ? s.ox === 'borrowed'
              ? 'autumn-promise'
              : 'autumn-free'
            : 'autumn-dispute'
          : opening
            ? s.ox === 'broken'
              ? 'winter-isolation'
              : 'winter-friend'
            : s.house < B.coldThreshold
              ? 'winter-cold'
              : 'winter-hearth';
  return EVENTS[id];
}
