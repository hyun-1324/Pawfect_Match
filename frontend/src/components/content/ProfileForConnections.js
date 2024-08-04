import { useParams } from "react-router-dom";
import useFetch from "../../tools/useFetch";
import { useNavigate } from "react-router-dom";
import { useAuth } from "../../tools/AuthContext";
import OnlineMark from "../../tools/OnlineMark";
import { useEffect } from "react";

const ProfileForConnections = () => {
  const { id } = useParams();

  const Navigate = useNavigate();
  const { statuses, login, isLoggedIn } = useAuth();

  const {
    data: user,
    isPending: isPending1,
    error: error1,
  } = useFetch(`http://localhost:3000/users/${id}`);
  const {
    data: userProfile,
    isPending: isPending2,
    error: error2,
  } = useFetch(`http://localhost:3000/users/${id}/profile`);
  const {
    data: userBio,
    isPending: isPending3,
    error: error3,
  } = useFetch(`http://localhost:3000/users/${id}/bio`);

  useEffect(() => {
    if (!isLoggedIn) {
      login();
    }
  }, [isLoggedIn, login]);

  if (isPending1 || isPending2 || isPending3) {
    return <div>Loading...</div>;
  }

  if (error1 || error2 || error3) {
    return (
      <div className="errorBox">
        Error: {error1?.message || error2?.message || error3?.message}
      </div>
    );
  }

  if (!user || !userProfile || !userBio) {
    return <div className="card centered">Loading data...</div>;
  }

  return (
    <div className="profile-container">
      <div className="profile-header">
        <h2>{user.dog_name}</h2>
      </div>
      <div className="notificationImageContainer">
        <img
          src={
            user.picture
              ? user.picture
              : `${process.env.PUBLIC_URL}/images/defaultProfile.png`
          }
          alt="Dog"
        />
        {OnlineMark(id, statuses)}
      </div>

      <h3>About me and my owner</h3>
      <p>{userProfile.about_me}</p>
      <h3>Bio</h3>
      <p>Gender: {userBio.gender}</p>
      <p>Neutered: {userBio.neutered ? "Yes" : "No"}</p>
      <p>Size: {userBio.size} kg</p>
      <p>Energy level: {userBio.energy_level}</p>
      <p>Favorite play style: {userBio.play_style}</p>
      <p>Age: {userBio.age}</p>

      <button className="chat-button" onClick={() => Navigate(`/chat/${id}`)}>
        <img
          className="button navButton"
          src={`${process.env.PUBLIC_URL}/images/chat.png`}
          alt="Open chat with user"
        />
      </button>
    </div>
  );
};
export default ProfileForConnections;
