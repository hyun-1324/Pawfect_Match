const fetchUserData = async (id, {signal}) => {
    const response = await fetch(`/users/${id}`, { signal });
    if (!response.ok) {
        const errorResponse = await response.json();
        const error = new Error();
        error.status = response.status;
        error.message = errorResponse.Message || "Unknown error";
        return { userData: null, error };
    }
    const data = await response.json(); // data.id, data.dog_name, data.picture
    return { userData: data, error: null };
};

export default fetchUserData;