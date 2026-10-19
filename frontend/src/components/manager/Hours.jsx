import { WEEKDAYS } from '../../lib/quote.js';
import { ALL_END, ALL_START, dayHoursLabel } from '../../lib/driverHours.js';
import { isAllDayHours } from '../../lib/planMonth.js';
import FactList from './FactList.jsx';
import TimeSelect from './TimeSelect.jsx';

export function HoursSummary({ week }) {
  return (
    <FactList
      className="hours-facts"
      rows={WEEKDAYS.map((day) => ({
        label: day.label,
        value: dayHoursLabel(week, day.id),
      }))}
    />
  );
}

export function HoursEditor({ week, setDay, toggleAllDay }) {
  return (
    <div className="hours-grid">
      {WEEKDAYS.map((day) => {
        const start = week[day.id]?.start || '';
        const end = week[day.id]?.end || '';
        const allDay = isAllDayHours({ start_time: start, end_time: end });
        return (
          <div key={day.id} className="hours-row">
            <span>{day.label}</span>
            <TimeSelect
              id={`hours-${day.id}-start`}
              value={start}
              emptyLabel="Off"
              onChange={(value) => setDay(day.id, 'start', value)}
            />
            <TimeSelect
              id={`hours-${day.id}-end`}
              value={end}
              emptyLabel="Off"
              onChange={(value) => setDay(day.id, 'end', value)}
            />
            <label className="hours-all">
              <input
                type="checkbox"
                checked={allDay}
                onChange={(e) => toggleAllDay(day.id, e.target.checked)}
              />
              All day
            </label>
          </div>
        );
      })}
    </div>
  );
}

export { ALL_END, ALL_START };
