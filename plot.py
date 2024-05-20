# !/usr/bin/python3
import numpy as np
import matplotlib.pyplot as plt

# parameters to modify
filename='processedPing01.data'
label='ping0.0001'
xlabel = 'ping time/s'
ylabel = 'RTT/s'
title='processedPing0.0001'
fig_name='pingtest0001.png'
bins=100 #adjust the number of bins to your plot


t = np.loadtxt(filename, delimiter=" ", dtype="float")

plt.plot(t[:,0], t[:,1], label=label)  # Plot some data on the (implicit) axes.
#Comment the line above and uncomment the line below to plot a CDF
#plt.hist(t[:,1], bins, density=True, histtype='step', cumulative=True, label=label)
plt.xlabel(xlabel)
plt.ylabel(ylabel)
plt.title(title)
plt.legend()
plt.savefig(fig_name)
plt.show()
