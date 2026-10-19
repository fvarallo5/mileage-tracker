import { useEffect, useState } from 'react';
import { supabase } from '../../supabase.js';

export default function PodPhoto({ path, alt = 'Delivery', className = 'pod-photo' }) {
  const [url, setUrl] = useState('');

  useEffect(() => {
    if (!path || !supabase) {
      setUrl('');
      return undefined;
    }
    let live = true;
    supabase.storage.from('receipts').createSignedUrl(path, 60 * 60).then(({ data }) => {
      if (live) setUrl(data?.signedUrl || '');
    }).catch(() => {
      if (live) setUrl('');
    });
    return () => {
      live = false;
    };
  }, [path]);

  if (!url) return null;
  return <img className={className} src={url} alt={alt} />;
}
