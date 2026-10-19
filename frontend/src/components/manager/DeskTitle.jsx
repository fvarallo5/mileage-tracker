import { useDeskChrome } from '../../context/DeskNav.jsx';
import { useTeam } from '../../context/TeamContext.jsx';

export default function DeskTitle({ title, sub, right, rail, mini }) {
  const { membership } = useTeam();
  const org = membership?.name || 'TrekTrack';
  useDeskChrome(() => ({
    header: {
      title,
      crumb: `${org} › ${title}`,
      sub,
      right,
    },
    rail: rail || null,
    mini: mini || null,
  }), [org, title, sub]);
  return null;
}
