import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';

const useFetch = (url) => {
  const [data, setData] = useState(null);
  const [isPending, setIsPending] = useState(true);
  const [error, setError] = useState(null);
  const navigate = useNavigate();

  useEffect(() => {
    const abortCont = new AbortController();
    const fetchData = async () => {
      try {
        const response = await fetch(url, { signal: abortCont.signal });
        if (!response.ok) {
          // Handle HTTP errors
          const errorResponse = await response.json();
          const error = new Error();
          error.status = response.status; // Include the status code
          error.message = errorResponse.Message || "Unknown error"; // Include the error message; 
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
          } else if (err.name === 'TypeError' && err.message === 'Failed to fetch') {
            // Network error or CORS issue
            setError({ message: "Network error: Unable to reach the server", status: 'NETWORK_ERROR' });
          } else {
          setError({ message: err.message, status: err.status });
        }
      }
    };

    fetchData();

    // Abort the fetch on cleanup
    return () => abortCont.abort();
  }, [url]);

  // Redirect to login page if unauthorized error
  useEffect(() => {
    if (error?.status === '401') {
      navigate('/login'); 
    } else if (error?.status === '404') {
      navigate('/notFound');
    }

  }, [error, navigate]); 

  return { data, isPending, error };
}

 
export default useFetch;