import { useState, useEffect } from 'react';

const useFetch = async (url) => {
  const [data, setData] = useState(null);
  const [isPending, setIsPending] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const abortCont = new AbortController();
    const fetchData = async () => {
      try {
        const response = await fetch(url, { signal: abortCont.signal });
        if (!response.ok) {
          // Handle HTTP errors
          const errorResponse = await response.json();
          const errorMessage = errorResponse.Message;
          const error = new Error(errorMessage);
          error.response = errorResponse; 
          throw error;
          }
        const data = await response.json();
        setData(data);
        setIsPending(false);
      } catch (err) {
          setIsPending(false);
          if (err.name === 'AbortError') {
              // The request was aborted
              console.log('Fetch aborted');
          } else if (err.response && err.response.Message) {
              // This is an HTTP error that was thrown manually in the try block
              setError(err.response.Message);
          } else {
              // This is likely a network error
              setError('Network error, please try again.');
          }
      }
    };

    fetchData();

    // Abort the fetch on cleanup
    return () => abortCont.abort();
  }, [url]);

  return { data, isPending, error };
}

 
export default useFetch;