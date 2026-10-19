import { ProfileSetup } from './Profile.jsx';

/** @deprecated Use ProfileSetup with includeMode. Kept for older imports. */
export default function CompanySetup({ onSignOut, onDone }) {
  return (
    <ProfileSetup
      onSignOut={onSignOut}
      includeMode
      onDone={(answers) =>
        onDone?.({
          companyKind: answers.companyKind,
          jobStyle: answers.jobStyle,
          defaultPayType: answers.defaultPayType,
          operatingMode: answers.operatingMode,
        })
      }
    />
  );
}
