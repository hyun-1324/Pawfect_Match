import React from 'react';


function AlertModal({ children, open, onClose }) {

  if (!open) return null;

  return (
    <>
      <div className="overlayStyle" onClick={onClose} />
      <div className="modalStyle">
        {children}
        <button className="textButton button" onClick={onClose}>Awesome!</button>
      </div>
    </>
  );
}

export default AlertModal;