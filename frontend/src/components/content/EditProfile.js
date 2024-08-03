import { useState, useEffect } from "react";
import { useNavigate } from "react-router-dom";
import useFetch from "../../tools/useFetch";
import Cropper from "react-easy-crop";
import getCroppedImg from "../../tools/getCroppedImg";

const EditProfile = () => {
  const [form, setForm] = useState({
    previous_password: "",
    password: "",
    confirm_password: "",
    add_picture: false,
    preferred_location: "Live",
    dog_name: "",
    gender: "male",
    neutered: false,
    size: 0,
    energy_level: "low",
    favorite_play_style: "wrestling",
    age: -1,
    preferred_distance: 1,
    preferred_gender: "any",
    preferred_neutered: false,
    about_me: "",
  });
  const [imageSrc, setImageSrc] = useState(null);
  const [crop, setCrop] = useState({ x: 0, y: 0 });
  const [zoom, setZoom] = useState(1);
  const [croppedAreaPixels, setCroppedAreaPixels] = useState(null); // [x, y, width, height]
  const [error, setError] = useState(null);
  const [isPending, setIsPending] = useState(false);
  const [controller, setController] = useState(null);

  const navigate = useNavigate();

  const { data: user, isPending: isPending1, error: error1 } = useFetch("http://localhost:8080/me");

  const {
    data: userProfile,
    isPending: isPending2,
    error: error2,
  } = useFetch("http://localhost:8080/me/profile");

  const {
    data: userBio,
    isPending: isPending3,
    error: error3,
  } = useFetch("http://localhost:8080/me/bio");

  useEffect(() => {
    if (user && userProfile && userBio) {
      setForm((prevForm) => ({
        ...prevForm,
        ...user,
        ...userProfile,
        ...userBio,
        password: "",
        confirm_password: "",
        add_picture: !!userProfile.profile_picture,
      }));
      if (userProfile.profile_picture) {
        setImageSrc(userProfile.profile_picture);
      }
    }
  }, [user, userProfile, userBio]);

  const handleChange = (name, value) => {
    setForm({
      ...form,
      [name]: value,
    });
  };

  const handleFileChange = async (e) => {
    if (e.target.files && e.target.files.length > 0) {
      const file = e.target.files[0];
      setImageSrc(URL.createObjectURL(file));
      handleChange("add_picture", true);
    }
  };

  const handleRemove = () => {
    setImageSrc(null);
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedAreaPixels(null);
    handleChange("add_picture", false);
    document.getElementById("file-input").value = "";
    URL.revokeObjectURL(imageSrc);
  };

  const handleRemoveExistingPicture = () => {
    setForm((prevForm) => ({
      ...prevForm,
      picture: null,
      add_picture: true,
    }));
    setImageSrc(null);
    setCrop({ x: 0, y: 0 });
    setZoom(1);
    setCroppedAreaPixels(null);
  };

  const handleClick = () => {
    document.getElementById("file-input").click();
  };

  const handleCropComplete = (_, croppedAreaPixels) => {
    setCroppedAreaPixels(croppedAreaPixels);
    if (!imageSrc && form.picture) {
      setForm((prevForm) => ({
        ...prevForm,
        croppedAreaPixels: croppedAreaPixels,
      }));
    }
  };

  useEffect(() => {
    // Cleanup function to abort the fetch if necessary
    return () => {
      if (controller) {
        controller.abort();
      }
    };
  }, [controller]);

  const handleSubmit = async (event) => {
    event.preventDefault();
    setIsPending(true);
    setError(null);
    const controller = new AbortController();
    setController(controller);

    try {
      const formData = new FormData();
      try {
        if (form.password || form.confirm_password || form.previous_password) {
          if (!form.previous_password) {
            throw new Error("Current password is required!");
          }
          if (!form.password.trim() || !form.confirm_password.trim()) {
            throw new Error("New password is required!");
          }
          if (form.password !== form.confirm_password) {
            throw new Error("Passwords do not match!");
          }
        }
        if (imageSrc) {
          const croppedImageBlob = await getCroppedImg(
            imageSrc,
            croppedAreaPixels
          );
          // Check image size
          if (croppedImageBlob.size > 2000000) {
            throw new Error("Image size must be less than 2 MB!");
          }
          formData.append(
            "profilePicture",
            croppedImageBlob,
            "profilePicture.png"
          );
        } else if (form.picture && form.croppedAreaPixels) {
          const croppedImageBlob = await getCroppedImg(
            form.picture,
            form.croppedAreaPixels
          );

          if (croppedImageBlob.size > 2000000) {
            throw new Error("Image size must be less than 2 MB!");
          }
          formData.append(
            "profilePicture",
            croppedImageBlob,
            "profilePicture.png"
          );
        }
      } catch (err) {
        setIsPending(false);
        setError(err.message);
        return;
      }

      if (imageSrc) {
        const croppedImageBlob = await getCroppedImg(
          imageSrc,
          croppedAreaPixels
        );
        formData.append(
          "profilePicture",
          croppedImageBlob,
          "profilePicture.png"
        );
      }

      form.age = Number(form.age);
      form.size = Number(form.size);
      form.preferred_distance = Number(form.preferred_distance);

      formData.append("json", JSON.stringify(form));

      let response = await fetch("http://localhost:8080/handle_profile", {
        method: "PATCH",
        body: formData,
        signal: controller.signal,
      });

      if (!response.ok) {
        // Handle HTTP errors
        const errorResponse = await response.json();
        throw new Error(errorResponse.Message || "Unknown error");
      }

      navigate("/myprofile");
    } catch (err) {
      setError(err.message);
    } finally {
      setIsPending(false);
    }
  };

  if (isPending1 || isPending2 || isPending3) return <div>Loading...</div>;
  if (error1 || error2 || error3)
    return (
      <div className="errorBox">Error: {error1?.message || error2?.message || error3?.message}</div>
    );

  return (
    <div className="card padded">
      <h2>Edit Your Profile</h2>
      <form className="twoColumnCard" onSubmit={handleSubmit}>
        <div className="oneColumnCardLeft">
          <h4>Change password</h4>
          <p>
            Change password by filling in the current password and new password.
            If you wish not to change the password, leave these fields empty.
          </p>
          <label htmlFor="currentPassword">Current password: </label>
          <br />
          <input
            type="password"
            id="currentPassword"
            name="previous_password"
            maxLength={60}
            value={form.previous_password}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <label htmlFor="password">New password: </label>
          <br />
          <input
            type="password"
            id="password"
            name="password"
            maxLength={60}
            value={form.password}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <br />
          <label htmlFor="confirmPassword">Repeat new password: </label>
          <br />
          <input
            type="password"
            id="confirmPassword"
            name="confirm_password"
            maxLength={60}
            value={form.confirm_password}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <br />
          <h4>Owner info</h4>
          <label htmlFor="prefLocation">My location: *</label>
          <br />
          <select
            name="preferred_location"
            id="prefLocation"
            value={form.preferred_location}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          >
            <option value="Live">Use my live location</option>
            <option value="Helsinki">Helsinki</option>
            <option value="Tampere">Tampere</option>
            <option value="Turku">Turku</option>
            <option value="Jyväskylä">Jyväskylä</option>
            <option value="Kuopio">Kuopio</option>
          </select>
          <h4>Pet info</h4>
          <label htmlFor="dogName">Name: *</label>
          <br />
          <input
            type="text"
            id="dogName"
            name="dog_name"
            maxLength={30}
            required
            value={form.dog_name}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <br />
          <label htmlFor="age">Age: *</label>
          <br />
          <input
            type="number"
            id="age"
            name="age"
            min={0}
            max={30}
            placeholder="age in years"
            required
            value={form.age === -1 ? "" : form.age}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <br />
          <label htmlFor="gender">Gender: *</label>
          <select
            name="gender"
            id="gender"
            value={form.gender}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          >
            <option value="male">male</option>
            <option value="female">female</option>
          </select>
          <br />
          <label htmlFor="size">Size: *</label>
          <br />
          <input
            type="number"
            placeholder="size in kilograms"
            id="size"
            name="size"
            min={1}
            max={100}
            required
            value={form.size === 0 ? "" : form.size}
            onChange={(e) =>
              handleChange(e.target.name, Number(e.target.value))
            }
          />
          <br />
          <label htmlFor="neutered">My dog is neutered/spayed: *</label>
          <input
            className="checkbox"
            type="checkbox"
            id="neutered"
            name="neutered"
            value={form.neutered}
            onChange={(e) => handleChange(e.target.name, e.target.checked)}
          />
          <br />
          <label htmlFor="energyLevel">Energy level: *</label>
          <select
            name="energy_level"
            id="energyLevel"
            value={form.energy_level}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          >
            <option value="low">low</option>
            <option value="medium">medium</option>
            <option value="high">high</option>
          </select>
          <br />
          <label htmlFor="favoritePlayStyle">Favorite play style: *</label>
          <select
            name="favorite_play_style"
            id="favoritePlayStyle"
            value={form.favorite_play_style}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          >
            <option value="wrestling">wrestling</option>
            <option value="lonely wolf">lonely wolf</option>
            <option value="cheerleading">cheerleading</option>
            <option value="chasing">chasing</option>
            <option value="tugging">tugging</option>
            <option value="ripping">ripping</option>
            <option value="soft touch">soft touch</option>
            <option value="body slamming">body slamming</option>
          </select>
          <br />
          <label htmlFor="aboutMe">About me and my owner:</label>
          <br />
          <textarea
            className="aboutMeBox"
            id="aboutMe"
            name="about_me"
            maxLength={255}
            value={form.about_me}
            placeholder="Tell something about your dog and yourself to the other users..."
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          />
          <br />
          <output className="formOutput" htmlFor="aboutMe">
            {form.about_me.length}/255 characters
          </output>
          <br />
          <h4>Upload a profile picture</h4>
          <input
            type="file"
            id="file-input"
            style={{ display: "none" }}
            accept="image/*"
            onChange={handleFileChange}
          />
          <div>
            <button type="button" className="button">
              <img
                src={`${process.env.PUBLIC_URL}/images/upload.png`}
                alt="upload"
                onClick={handleClick}
              />
            </button>
            {imageSrc && (
              <button type="button" className="button" onClick={handleRemove}>
                <img
                  src={`${process.env.PUBLIC_URL}/images/remove.png`}
                  alt="remove"
                ></img>
              </button>
            )}
            {!imageSrc && form.picture && (
              <button
                type="button"
                className="button"
                onClick={handleRemoveExistingPicture}
              >
                <img
                  src={`${process.env.PUBLIC_URL}/images/remove.png`}
                  alt="remove existing"
                />
              </button>
            )}
          </div>
          {!imageSrc && !form.picture && <p>No file uploaded!</p>}
          {(imageSrc || form.picture) && (
            <p>
              File uploaded! <br />
              Crop and zoom the picture here if needed:
            </p>
          )}
          {imageSrc && (
            <div style={{ position: "relative", width: 300, height: 300 }}>
              <div>
                <Cropper
                  image={imageSrc}
                  crop={crop}
                  zoom={zoom}
                  aspect={1}
                  onCropChange={setCrop}
                  onZoomChange={setZoom}
                  onCropComplete={handleCropComplete}
                />
              </div>
            </div>
          )}
          {!imageSrc && form.picture && (
            <div>
              <div style={{ position: "relative", width: 300, height: 300 }}>
                <Cropper
                  image={form.picture}
                  crop={crop}
                  zoom={zoom}
                  aspect={1}
                  onCropChange={setCrop}
                  onZoomChange={setZoom}
                  onCropComplete={handleCropComplete}
                />
              </div>
              <p>Current profile picture</p>
            </div>
          )}

          <br />
          <h4>Preferences</h4>
          <p>Play mate should be...</p>
          <label htmlFor="prefGender">Gender: *</label>
          <select
            name="preferred_gender"
            id="prefGender"
            value={form.preferred_gender}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
          >
            <option value="any">any</option>
            <option value="male">male</option>
            <option value="female">female</option>
          </select>
          <br />
          <label htmlFor="prefNeutered">Neutered/spayed: *</label>
          <input
            className="checkbox"
            type="checkbox"
            id="prefNeutered"
            name="preferred_neutered"
            value={form.preferred_neutered}
            onChange={(e) => handleChange(e.target.name, e.target.checked)}
          />
          <br />
          <label htmlFor="prefDistance">Located within: *</label>
          <input
            type="range"
            id="prefDistance"
            name="preferred_distance"
            value={form.preferred_distance}
            onChange={(e) => handleChange(e.target.name, e.target.value)}
            min={1}
            max={30}
          />
          <output className="formOutput" htmlFor="prefDistance">
            {form.preferred_distance} km
          </output>
          <br />
        </div>
        <div className="oneColumnCardRight">
          {error && (
            <div className="errorBox flexEnd">
              Error:
              <br />
              {error}
            </div>
          )}
          {!isPending && (
            <button className="button" type="submit">
              <img
                src={`${process.env.PUBLIC_URL}/images/save.png`}
                alt="Register"
              ></img>
            </button>
          )}
          {isPending && (
            <button className="button" disabled>
              <img
                src={`${process.env.PUBLIC_URL}/images/loading.png`}
                alt="Loading..."
              ></img>
            </button>
          )}
        </div>
      </form>
    </div>
  );
};

export default EditProfile;
