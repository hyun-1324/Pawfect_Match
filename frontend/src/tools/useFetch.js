import { useState, useEffect } from 'react';

const useFetch = (url) => {
  const [data, setData] = useState(null);
  const [isPending, setIsPending] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const abortCont = new AbortController();

    fetch(url, { signal: abortCont.signal })
    .then(response => {
    if (!response.ok) { 
        const errorText = response.text();
        throw new Error(errorText);
    } 
    return response.json();
    })
    .then(data => {
    setIsPending(false);
    setData(data);
    setError(null);
    })
    .catch(err => {
    if (err.name !== 'AbortError') {
        setIsPending(false);
        setError(err.message);
    }
    })
   
    // abort the fetch
    return () => abortCont.abort();
  }, [url])

  return { data, isPending, error };
}
 
export default useFetch;