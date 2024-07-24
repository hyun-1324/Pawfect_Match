const fetchFromEndpoint = async (url, {signal}) => {
    const response = await fetch(url, { signal: signal });
    if (!response.ok) {
    // Handle HTTP errors
    const errorResponse = await response.json();
    const error = new Error();
    error.status = response.status; // Include the status code
    error.message = errorResponse.Message || "Unknown error"; // Include the error message; 
    return { data: null, error };
    }
    const data = await response.json();
    return { data, error: null };
    
  };

  export default fetchFromEndpoint;