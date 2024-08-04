import { useAuth } from "../../tools/AuthContext";
import { useNavigate } from "react-router-dom";
import { useState, useEffect, useCallback} from "react";
import fetchFromEndpoint from "../../tools/fetchFromEndpoint";
import OnlineMark from "../../tools/OnlineMark";

const Connections = () => {
    const { loggedIn, statuses, friendRequests, sendJsonMessage, lastJsonMessage, login, clearFriendNotification, chatList } = useAuth();
    const navigate = useNavigate();
    const [errorMessage, setErrorMessage] = useState(null);
    const [connectionsList, setConnectionsList] = useState([]); /* []int */
    const [connections, setConnections] = useState([]);  /* []{id, dog_name, picture} */ 
    const [requests, setRequests] = useState([]);
    const [triggerFetch, setTriggerFetch] = useState(false);

    // Connect websocket if not already connected
    useEffect(() => {
        if (!loggedIn) {
            login();
        }
    }, [loggedIn, login]);

    // Fetch connectionsList at the beginning and when triggerFetch changes
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
            fetchFromEndpoint("http://localhost:3000/connections", { signal })
            .then(({ data, error }) => {
                if (error) {
                    if (error.status === 401) {
                        navigate("/login");
                    } else {
                        setErrorMessage(error.message);
                    }
                }
                if (data?.ids) {
                    setConnectionsList(data.ids);
                } else {
                    setConnectionsList([]);
                }
            })
            .catch((error) => {
                if (error.name === "AbortError") {
                } else {
                    console.error(error);
                    setErrorMessage(error.message);
                }
            })

        return () => abortController.abort();
    }, [navigate, triggerFetch]);

    // Trigger connections fetch when receiving new connection event
    useEffect(() => {
        if (lastJsonMessage?.event === "new_connection") {
            setTriggerFetch(prev => !prev);
        }
    }, [lastJsonMessage]);

    // Get other information needed for connections
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        const connectionsMap = new Map();
        if (connectionsList.length > 0 && !errorMessage) {
            setConnections([]);
            Promise.allSettled(connectionsList.map((id) => 
                fetchFromEndpoint(`http://localhost:3000/users/${id}`, {signal})
                    .then(({ data, error }) => {
                        if (error) {
                            if (error.status === 401) {
                                navigate("/login");
                            } else {
                                setErrorMessage(error.message);
                            }
                        } else {
                            connectionsMap.set(Number(id), data);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                        } else {
                            setErrorMessage(error.message);
                        }
                    })
                )).then(() => {
                    //Sort connectionsMap by the order of connectionsList
                    const sortedConnections = connectionsList.map((id) => connectionsMap.get(id)).filter(Boolean);
                    setConnections(sortedConnections);
                });
                   
        } else if (connectionsList.length === 0) {
            setConnections([]);
        }
        return () => abortController.abort(); 
    }, [connectionsList, errorMessage, navigate]);

    // Get user information needed for requests
    useEffect(() => {
        const abortController = new AbortController(); 
        const signal = abortController.signal; 
        if ( friendRequests.length > 0 && !errorMessage) {
            setRequests([]);
            Promise.allSettled(friendRequests.map((id) => 
                fetchFromEndpoint(`http://localhost:3000/users/${id}`, {signal})
                    .then(({ data, error }) => {
                        if (error) {
                            if (error.status === 401) {
                                navigate("/login");
                            } else {
                            setErrorMessage(error.message);
                            }
                        } else {
                            setRequests((prevList) => [...prevList, data]);
                        }
                    })
                    .catch((error) => {
                        if (error.name === "AbortError") {
                        } else {
                            setErrorMessage(error.message);
                        }
                    })
            ));
        } else if (friendRequests.length === 0) {
            setRequests([]);
        }

        return () => abortController.abort(); 
    }, [friendRequests, errorMessage, navigate]);

    // Functions to handle removing connections and accepting/dismissing requests
    const handleRemoveConnection = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "decline_request", data: dataObject });
        // Find room that has the same user_id as the userId
        const room = chatList.find((room) => room.user_id === userId);
        const roomId = { room_id: String(room.id) };
        sendJsonMessage({ event: "leave_room", data: roomId });
        setTriggerFetch(prev => !prev);
    }, [sendJsonMessage, chatList]);

    const handleRemoveRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "decline_request", data: dataObject });
        clearFriendNotification(userId);
    }, [sendJsonMessage, clearFriendNotification]);

    const handleAcceptRequest = useCallback((userId) => {
        const dataObject = { id: userId };
        sendJsonMessage({ event: "accept_request", data: dataObject });
        clearFriendNotification(userId);
        
    }, [sendJsonMessage, clearFriendNotification]);

    // Function to generate connection cards
    const makeConnectionCards = (connections, OnlineMark, statuses) => {
        if (!connections || connections.length === 0) {
            return (
                <div className="card centered">
                    <h3>You have no connections.</h3>
                </div>
            );
        }

        return connections.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <div className="notificationImageContainer">
                    <img className="cardPicture" 
                        src={
                            dogData.picture
                            ? dogData.picture
                            : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
                        } 
                        alt="dog" 
                        onClick={() => navigate(`/profileforconnections/${dogData.id}`)} />
                    {OnlineMark(dogData.id, statuses)}
                </div>
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                        
                    <div className="buttonContainer">
                        <button className="button userCardButton" 
                            onClick={() => handleRemoveConnection(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/dismiss.png`} 
                                alt="Remove connection" />
                        </button>
                    </div>
                </div>
                
            </div>
        ));
    };

    // Function to generate request cards
    const makeRequestCards = (requests) => {
        if (!requests || requests.length === 0) {
            return <></>;
        }

        return requests.map((dogData) => (
            <div key={dogData.id} className="card userCard">
                <img className="cardPicture" 
                    src={
                        dogData.picture
                        ? dogData.picture
                        : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
                    } 
                    alt="dog" 
                    onClick={() => navigate(`/profile/${dogData.id}`)} />
                <div className="nameAndButtons">
                    <p>{dogData.dog_name}</p>
                    <div className="buttonContainer">
                        <button className="button userCardButton" 
                            onClick={() => handleAcceptRequest(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/accept.png`} 
                                alt="Accept request" />
                        </button>
                        <button className="button userCardButton" 
                            onClick={() => handleRemoveRequest(dogData.id)}>
                            <img 
                                src={`${process.env.PUBLIC_URL}/images/dismiss.png`} 
                                alt="Dismiss request" />
                        </button>
                    </div>
                </div>
                
            </div>
        ));
    }

    // Return the component
    return (
    <div>
        <h2>Connections</h2>
        {errorMessage && <div className="errorBox">Error:<br />{errorMessage}</div>}
        {requests?.length > 0 && <h3>New connection requests:</h3>}
        <div className="twoColumnCard">
            {makeRequestCards(requests)}
        </div>
        <h3>My connections:</h3>
        <div className="twoColumnCard">
            {makeConnectionCards(connections, OnlineMark, statuses)}
        </div>
        
    </div>

    )
  
} 
export default Connections;