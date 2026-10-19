export default function Module({ title, children, className = '', fill = false, actions }) {
  return (
    <section className={`mod${fill ? ' mod-fill' : ''}${className ? ` ${className}` : ''}`}>
      {title || actions ? (
        <div className="mod-head-row">
          {title ? <h2 className="mod-head">{title}</h2> : <span />}
          {actions ? <div className="mod-actions">{actions}</div> : null}
        </div>
      ) : null}
      <div className="mod-body">{children}</div>
    </section>
  );
}
