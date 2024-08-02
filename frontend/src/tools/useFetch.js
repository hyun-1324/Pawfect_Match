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
          let errorResponse;
                try {
                    errorResponse = await response.json();
                } catch (jsonError) {
                    if (jsonError instanceof SyntaxError) {
                        throw new Error("Failed to parse error response");
                    } else {
                        throw jsonError;
                    }
                }
          const error = new Error();
          error.status = response.status; // Include the status code
          error.message = errorResponse.Message || "Unknown error"; // Include the error message; 
          setError(error);
          throw error;
          }
        const data = await response.json();
        setData(data);
        setIsPending(false);
      } catch (err) {
          setIsPending(false);
          if (err.name === 'AbortError') {
              // The request was aborted
          } else if (err.message === "Failed to parse error response") {
              setError({ message: 'Can not reach server', status: 500 });
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
    if (error?.status === 401) {
      navigate('/login'); 
    } else if (error?.status === 404) {
      navigate('/notFound');
    }

  }, [error, navigate]); 

  return { data, isPending, error };
}

 
export default useFetch;