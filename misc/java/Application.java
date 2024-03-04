package hello;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.net.InetAddress;

@SpringBootApplication
@RestController
public class Application {

	@RequestMapping("/")
	public String home() {
		String hostaddress = "";
		String hostname = "";
		try {
			hostname = InetAddress.getLocalHost().getHostName();
			hostaddress = InetAddress.getLocalHost().getHostAddress();
		} catch (Exception e){}
		return "Hello GitOps World (" + hostname + " / " + hostaddress + ")\n";
	}

	public static void main(String[] args) {
		SpringApplication.run(Application.class, args);
	}

}
